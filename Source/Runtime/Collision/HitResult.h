#pragma once
#include "Core/Types.h"
#include "Math/Vector.h"

class UPrimitiveComponent;
class AActor;

struct FHitResult
{
	int32 FaceIndex = -1;

	float Time = 1.0f;          // 스윕: Delta 중 실제로 이동한 비율 (0~1)
	float Distance = FLT_MAX;

	FVector Location;           // 스윕: 멈춘 위치
	FVector ImpactPoint;        // 맞은 물체 표면의 접촉점
	FVector Normal;             // 스윕: 움직인 도형을 밀어내는 방향
	FVector ImpactNormal;

	FVector TraceStart;
	FVector TraceEnd;

	float PenetrationDepth = 0.0f;

	bool bBlockingHit = false;
	bool bStartPenetrating = false;

	UPrimitiveComponent* HitComponent = nullptr;
	AActor* HitActor = nullptr;

	FHitResult() = default;

	explicit FHitResult(float InTime)
	{
		Time = InTime;
	}

	void Init()
	{
		*this = FHitResult();
	}

	void Init(const FVector& Start, const FVector& End)
	{
		Init();
		TraceStart = Start;
		TraceEnd = End;
	}

	AActor* GetActor() const { return HitActor; }
	UPrimitiveComponent* GetComponent() const { return HitComponent; }
};
