#include "EnginePCH.h"

#include "ScriptComponent.h"

#include "Engine/Engine.h"
#include "Scripting/LuaVM.h"

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
    if (!EndPlayFunction.valid())
    {
        return;
    }

    sol::protected_function_result Result = EndPlayFunction();

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

    sol::protected_function_result Result = OverlapFunction(OtherActor);

    if (!Result.valid())
    {
        sol::error Error = Result;
        HTR_LOG(Error, "[Lua] {}", Error.what());
    }
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

    BindScriptContext();

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

    return true;
}

void UScriptComponent::BindScriptContext()
{
    Environment["self"] = GetOwner();

    Environment.set_function(
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
	NewEnvironment["self"] = GetOwner();

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

    void BindScriptContext();

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