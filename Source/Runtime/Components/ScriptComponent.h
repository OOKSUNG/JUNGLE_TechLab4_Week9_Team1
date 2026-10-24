#pragma once
#include "ActorComponent.h"

#include <sol/sol.hpp>

class FLuaVM;

class UScriptComponent : public UActorComponent
{
	DECLARE_CLASS(UScriptComponent, UActorComponent)

	REFLECT_START(ClassName)
		REFLECT_END()

public:
	virtual ~UScriptComponent() override {};

	virtual void InitializeComponent() override;
	virtual void BeginPlay() override;
	virtual void TickComponent(float DeltaTime) override;
	virtual void EndPlay() override;
	void OnOverlap(AActor* OtherActor);

	bool CreateScriptFromTemplate(const FString& SceneName, const FString& ActorName);
	bool LoadScript();
	bool EnsureScriptFile();

	void BindScriptContext();

	const FString& GetScriptPath() const { return ScriptPath; }

private:
	sol::environment Environment;

	sol::protected_function BeginPlayFunction;
	sol::protected_function TickFunction;
	sol::protected_function EndPlayFunction;
	sol::protected_function OverlapFunction;

	FLuaVM* LuaVM;
	sol::state* State;

	FString ScriptPath;

	std::filesystem::file_time_type LastWriteTime{};
	float HotReloadCheckTimer = 0.0f;

	bool ReloadScript();
	void CheckHotReload(float DeltaTime);
};