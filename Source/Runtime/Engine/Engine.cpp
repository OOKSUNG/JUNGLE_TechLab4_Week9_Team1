#include "EnginePCH.h"
#include "Engine.h"

#include "Components/ScriptComponent.h"

UEngine* GEngine = nullptr;
UEngine::~UEngine() = default;

bool UEngine::Init()
{
	UScriptComponent::StaticClass();

	AssetManager = NewObject<UAssetManager>();
	/*World = FObjectFactory::ConstructObject<UWorld>();

	if (!World || !World->Init()) return false;*/

	AudioSystem = MakeUnique<FAudioSystem>();

	if (!AudioSystem->Initialize())
	{
		HTR_LOG(Warning, "[Startup] Audio is unavailable; sounds will be skipped");
	}

	LuaVM = MakeUnique<FLuaVM>();

	if (!LuaVM->Initialize())
	{
		HTR_LOG(Error, "[Startup] Lua VM initialization failed");
		return false;
	}

	// 초기 연결 확인용입니다.
	if (!LuaVM->ExecuteString(
		"Log('Lua VM startup test', 123, true)",
		"@VMStartup"
	))
	{
		return false;
	}

	// Lua 파일을 실행한다.
	if (!LuaVM->ExecuteFile("Assets/Scripts/VMTest.lua"))
	{
		return false;
	}

 	return true;
}

FWorldContext& UEngine::CreateNewWorldContext(EWorldType WorldType)
{
	FWorldContext* NewWorldContext = new FWorldContext();
	WorldList.Add(NewWorldContext);
	NewWorldContext->WorldType = WorldType;
	NewWorldContext->ContextHandle = FName();

	return *NewWorldContext;
}

FWorldContext* UEngine::GetWorldContextFromWorld(const UWorld* InWorld)
{
	for (FWorldContext& WorldContext : WorldList)
	{
		if (WorldContext.World() == InWorld)
		{
			return &WorldContext;
		}
	}
	return nullptr;
}

void UEngine::DestroyWorldContext(UWorld* InWorld)
{
	for (int32 idx = 0; idx < WorldList.Num(); ++idx)
	{
		if (WorldList[idx].World() == InWorld)
		{
			//WorldContextDestroyedEvent.Broadcast(WorldList[idx]);

			WorldList[idx].SetCurrentWorld(NULL);
			WorldList.RemoveAt(idx);
			break;
		}
	}
}

void FWorldContext::SetCurrentWorld(UWorld* World)
{
	ThisCurrentWorld = World;
}
