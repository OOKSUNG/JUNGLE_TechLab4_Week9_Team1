#include "EnginePCH.h"

#include "ScriptComponent.h"

#include "Engine/Engine.h"
#include "Scripting/LuaVM.h"
#include "Components/ShapeComponent.h"
#include "GameFramework/Actor.h"

UScriptComponent::~UScriptComponent()
{
    UnbindCollisionEvents();
}

void UScriptComponent::InitializeComponent()
{
	Super::InitializeComponent();
	
    LuaVM = GEngine->GetLuaVM();
    State = LuaVM->GetState();

    if (!EnsureScriptFile()) 
    {
		return;
    }

    PrimaryComponentTick.bCanEverTick = true;
}

void UScriptComponent::BeginPlay()
{
	Super::BeginPlay();

    LoadScript();
    // 함수 객체 대신 this를 통해 현재 Lua 함수를 조회하므로 Hot Reload에도 유지된다.
    BindCollisionEvents();

    std::error_code ErrorCode;

    LastWriteTime =  std::filesystem::last_write_time(ScriptPath, ErrorCode);

    if (ErrorCode)
    {
        HTR_LOG(Warning, "[Lua] Cannot read script timestamp: {}", ScriptPath);
    }

    if (!BeginPlayFunction.valid())
    {
        return;
    }

    sol::protected_function_result Result = BeginPlayFunction();

    if (!Result.valid())
    {
        sol::error Error = Result;
        HTR_LOG(Error, "[Lua] {}", Error.what());
    }
}

void UScriptComponent::TickComponent(float DeltaTime)
{
	Super::TickComponent(DeltaTime);
    
    // 파일 변경 감지 체크
    CheckHotReload(DeltaTime);

    if (!TickFunction.valid())
    {
        return;
    }

    sol::protected_function_result Result = TickFunction(DeltaTime);

    if (!Result.valid())
    {
        sol::error Error = Result;
        HTR_LOG(Error, "[Lua] {}", Error.what());
    }
}

void UScriptComponent::EndPlay()
{
    UnbindCollisionEvents();
    Super::EndPlay();

    if (!EndPlayFunction.valid())
    {
        return;
    }

    sol::protected_function Function = EndPlayFunction;
    sol::protected_function_result Result = Function();

    if (!Result.valid())
    {
        sol::error Error = Result;
        HTR_LOG(Error, "[Lua] {}", Error.what());
    }
}

void UScriptComponent::OnOverlap(AActor* OtherActor)
{
    if (!OverlapFunction.valid())
    {
        return;
    }

    // Lua에서 DestroySelf()를 호출해도 실행 중인 함수 참조는 살아 있어야 한다.
    sol::protected_function Function = OverlapFunction;
    sol::protected_function_result Result = Function(OtherActor);

    if (!Result.valid())
    {
        sol::error Error = Result;
        HTR_LOG(Error, "[Lua] {}", Error.what());
    }
}

void UScriptComponent::OnEndOverlap(AActor* OtherActor)
{
    if (!EndOverlapFunction.valid())
        return;

    sol::protected_function Function = EndOverlapFunction;
    sol::protected_function_result Result = Function(OtherActor);
    if (!Result.valid())
    {
        sol::error Error = Result;
        HTR_LOG(Error, "[Lua] OnEndOverlap: {}", Error.what());
    }
}

void UScriptComponent::OnHit(AActor* OtherActor, const FHitResult& Hit)
{
    if (!HitFunction.valid())
        return;

    sol::protected_function Function = HitFunction;
    // Sweep의 임시 HitResult를 Lua에 참조로 남기지 않는다.
    sol::protected_function_result Result = Function(OtherActor, FHitResult(Hit));
    if (!Result.valid())
    {
        sol::error Error = Result;
        HTR_LOG(Error, "[Lua] OnHit: {}", Error.what());
    }
}

void UScriptComponent::BindCollisionEvents()
{
    UnbindCollisionEvents();
    AActor* Owner = GetOwner();
    if (!Owner)
        return;

    CollisionCallbackLifetime = MakeShared<bool>(true);
    TWeakPtr<bool> Lifetime = CollisionCallbackLifetime;
    for (UActorComponent* Component : Owner->GetComponents())
    {
        UShapeComponent* Shape = Cast<UShapeComponent>(Component);
        if (!Shape)
            continue;

        FCollisionBinding Binding{};
        Binding.ShapeUUID = Shape->GetUUID();
        Binding.BeginOverlapHandle = Shape->OnComponentBeginOverlap.Add(
            [this, Lifetime](UPrimitiveComponent*, AActor* OtherActor, UPrimitiveComponent*)
            {
                if (!Lifetime.expired())
                    OnOverlap(OtherActor);
            });
        Binding.EndOverlapHandle = Shape->OnComponentEndOverlap.Add(
            [this, Lifetime](UPrimitiveComponent*, AActor* OtherActor, UPrimitiveComponent*)
            {
                if (!Lifetime.expired())
                    OnEndOverlap(OtherActor);
            });
        Binding.HitHandle = Shape->OnComponentHit.Add(
            [this, Lifetime](UPrimitiveComponent*, AActor* OtherActor, UPrimitiveComponent*, const FHitResult& Hit)
            {
                if (!Lifetime.expired())
                    OnHit(OtherActor, Hit);
            });
        CollisionBindings.Add(Binding);
    }
}

void UScriptComponent::UnbindCollisionEvents()
{
    CollisionCallbackLifetime.reset();
    for (const FCollisionBinding& Binding : CollisionBindings)
    {
        // Shape가 먼저 삭제되었거나 Actor의 소멸자가 Components를 비운 경우도 처리한다.
        for (UObject* Object : GUObjectArray)
        {
            if (Object->GetUUID() != Binding.ShapeUUID)
                continue;

            if (UShapeComponent* Shape = Cast<UShapeComponent>(Object))
            {
                Shape->OnComponentBeginOverlap.RemoveHandler(Binding.BeginOverlapHandle);
                Shape->OnComponentEndOverlap.RemoveHandler(Binding.EndOverlapHandle);
                Shape->OnComponentHit.RemoveHandler(Binding.HitHandle);
            }
            break;
        }
    }
    CollisionBindings.Reset();
}

bool UScriptComponent::CreateScriptFromTemplate(const FString& SceneName, const FString& ActorName)
{
    const std::filesystem::path TemplatePath = "Assets/Scripts/template.lua";
    const std::filesystem::path NewScriptPath = std::filesystem::path("Assets/Scripts") / 
        std::format("{}_{}.lua", SceneName, ActorName);

    if (!std::filesystem::exists(TemplatePath))
    {
        HTR_LOG(Error, "[Lua] Template not found: {}", TemplatePath.string());
        return false;
    }

    // 기존 스크립트는 절대 덮어쓰지 않습니다.
    if (!std::filesystem::exists(NewScriptPath))
    {
        std::error_code ErrorCode;

        std::filesystem::copy_file(
            TemplatePath,
            NewScriptPath,
            std::filesystem::copy_options::none,
            ErrorCode
        );

        if (ErrorCode)
        {
            HTR_LOG(
                Error,
                "[Lua] Failed to create script '{}': {}",
                NewScriptPath.string(),
                ErrorCode.message()
            );

            return false;
        }
    }

    ScriptPath = NewScriptPath.string();
    return true;
}

bool UScriptComponent::LoadScript()
{
    if (!LuaVM)
    {
        return false;
    }

    if (!State)
    {
        return false;
    }

    Environment = sol::environment(*State, sol::create, State->globals());

    if (!Environment)
    {
        return false;
    }

    BindScriptContext(Environment);

    sol::protected_function_result Result = State->safe_script_file
        (
            ScriptPath,
            Environment,
            sol::script_pass_on_error
        );

    if (!Result.valid())
    {
        sol::error Error = Result;
        HTR_LOG(Error, "[Lua] Failed to load '{}': {}", ScriptPath, Error.what());
        return false;
    }

    BeginPlayFunction = Environment["BeginPlay"];
    TickFunction = Environment["Tick"];
    EndPlayFunction = Environment["EndPlay"];
    OverlapFunction = Environment["OnOverlap"];
    EndOverlapFunction = Environment["OnEndOverlap"];
    HitFunction = Environment["OnHit"];

    return true;
}

void UScriptComponent::BindScriptContext(sol::environment& TargetEnvironment)
{
	AActor* Owner = GetOwner();

	TargetEnvironment["self"] = Owner;
    TargetEnvironment["scriptPath"] = ScriptPath;

	if (Owner)
	{
		if (UWorld* World = Owner->GetWorld())
		{
			TargetEnvironment["sceneName"] =
			    World->GetSceneName();
		}
	}

    TargetEnvironment.set_function(
        "DestroySelf",
        [this]()
        {
            if (AActor* Owner = GetOwner())
            {
                Owner->Destroy();
            }
        }
    );
}

void UScriptComponent::CheckHotReload(float DeltaTime)
{
    HotReloadCheckTimer += DeltaTime;

    if (HotReloadCheckTimer < 0.25f)
    {
        return;
    }

    HotReloadCheckTimer = 0.0f;

    std::error_code ErrorCode;

    const auto CurrentWriteTime =
        std::filesystem::last_write_time(
            ScriptPath,
            ErrorCode
        );

    if (ErrorCode)
    {
        return;
    }

    if (CurrentWriteTime == LastWriteTime)
    {
        return;
    }

    // 같은 변경을 매 프레임 다시 감지하지 않도록 갱신
    LastWriteTime = CurrentWriteTime;

    ReloadScript();
}

bool UScriptComponent::ReloadScript()
{
	FLuaVM* LuaVM = GEngine->GetLuaVM();

	if (!LuaVM || !LuaVM->IsInitialized())
	{
		return false;
	}

	sol::state* State = LuaVM->GetState();

	if (!State)
	{
		return false;
	}

	// 기존 Environment는 아직 유지
	sol::environment NewEnvironment(*State, sol::create, State->globals());

	// 현재 액터 컨텍스트를 새 환경에도 다시 넣어야 함
	BindScriptContext(NewEnvironment);

	sol::protected_function_result Result =
		State->safe_script_file(ScriptPath, NewEnvironment, sol::script_pass_on_error);

    if (!Result.valid())
    {
        sol::error Error = Result;
        HTR_LOG(Error, "[Lua] {}", Error.what());
        return false;
    }

	// 새 스크립트가 정상일 때만 기존 환경 교체
	Environment = std::move(NewEnvironment);

	BeginPlayFunction = Environment["BeginPlay"];
	TickFunction = Environment["Tick"];
	EndPlayFunction = Environment["EndPlay"];
	OverlapFunction = Environment["OnOverlap"];
	EndOverlapFunction = Environment["OnEndOverlap"];
	HitFunction = Environment["OnHit"];
    
    sol::protected_function ReloadFunction = Environment["OnReload"];

    if (ReloadFunction.valid())
    {
        sol::protected_function_result Result = ReloadFunction();

        if (!Result.valid())
        {
            sol::error Error = Result;
            HTR_LOG(Error, "[Lua] {}", Error.what());
        }
    }

    PrimaryComponentTick.bCanEverTick = true;

	HTR_LOG(Info, "[Lua] Hot reload succeeded: {}", ScriptPath);

	return true;
}

bool UScriptComponent::EnsureScriptFile()
{
	AActor* Owner = GetOwner();

	if (!Owner)
	{
		HTR_LOG(Error, "[Lua] ScriptComponent has no owner");
		return false;
	}

	UWorld* World = Owner->GetWorld();

	if (!World)
	{
		HTR_LOG(Error, "[Lua] ScriptComponent owner has no world");
		return false;
	}

	const FString SceneName = World->GetSceneName();
	const FString ActorName = Owner->GetName();

	return CreateScriptFromTemplate(SceneName, ActorName);
}
