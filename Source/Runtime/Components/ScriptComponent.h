#include "ActorComponent.h"

#include <sol/sol.hpp>

class FLuaVM;

class UScriptComponent : UActorComponent
{
	DECLARE_CLASS(UScriptComponent, UActorComponent)

	REFLECT_START(ClassName)
		REFLECT_END()

public:
	virtual ~UScriptComponent() override;

	virtual void InitializeComponent() override;
	virtual void BeginPlay() override;
	virtual void TickComponent(float DeltaTime) override;
	void EndPlay();
	void OnOverlap(AActor* OtherActor);

	bool CreateScriptFromTemplate(const FString& SceneName, const FString& ActorName);
	bool LoadScript();

	void BindScriptContext();
	

private:
	sol::environment Environment;

	sol::protected_function BeginPlayFunction;
	sol::protected_function TickFunction;
	sol::protected_function EndPlayFunction;
	sol::protected_function OverlapFunction;

	FLuaVM* LuaVM;
	sol::state* State;

	FString ScriptPath;
};