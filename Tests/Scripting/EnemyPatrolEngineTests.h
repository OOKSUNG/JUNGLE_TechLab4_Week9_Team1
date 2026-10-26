#pragma once

#include <format>
#include "Core/EngineString.h"
#include "Core/EngineLog.h"

class FPatrolLogSink final : public ILogSink {
public:
	void OnLog(ELogVerbosity Verbosity, const FString& Message) override;
};

class AActor;
class USceneComponent;

bool ValidateMeshRotation(AActor& Actor, USceneComponent& Component);
int main();
