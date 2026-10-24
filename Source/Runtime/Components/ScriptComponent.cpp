#include "EnginePCH.h"

#include "ScriptComponent.h"

#include "Engine/Engine.h"
#include "Scripting/LuaVM.h"

void UScriptComponent::InitializeComponent()
{
	Super::InitializeComponent();
	
    LuaVM = GEngine->GetLuaVM();
    State = LuaVM->GetState();

    UWorld* World = GetOwner()->GetWorld();

    FString SceneName = World->GetSceneName();
    FString ActorName = GetOwner()->GetName();

    CreateScriptFromTemplate(SceneName, ActorName);
}

void UScriptComponent::BeginPlay()
{
	Super::BeginPlay();

    LoadScript();

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