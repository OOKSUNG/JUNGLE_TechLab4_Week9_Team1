#pragma once

#include <memory>
#include "CameraShakeBase.h"

// 활성 쉐이크를 구분하는 핸들. 0은 유효하지 않다.
using FCameraShakeHandle = uint32;
constexpr FCameraShakeHandle InvalidCameraShakeHandle{ 0 };

// 활성 쉐이크 목록 관리 (언리얼 UCameraModifier_CameraShake 내부 로직 대응).
// 모디파이어 베이스가 생기면 UCameraModifier_CameraShake::ModifyCamera가 Update만 호출하면 된다.
class FCameraShakeManager {
public:
	// 쉐이크의 소유권을 넘겨받아 재생한다.
	// bSingleInstance이고 같은 Name이 재생 중이면 그 쉐이크를 재시작하고 기존 핸들을 반환한다.
	FCameraShakeHandle AddShake(std::unique_ptr<FCameraShakeBase> Shake, float Scale = 1.0f,
		ECameraShakePlaySpace PlaySpace = ECameraShakePlaySpace::CameraLocal,
		const FRotator& UserPlaySpaceRot = FRotator{});

	void RemoveShake(FCameraShakeHandle Handle, bool bImmediately = false);
	void RemoveAllShakesByName(const FString& Name, bool bImmediately = false);
	void RemoveAllShakes(bool bImmediately = false);

	// 모든 쉐이크를 갱신해 InOutPOV에 합성하고, 끝난 쉐이크를 목록에서 뺀다.
	// Alpha는 모디파이어 전체의 켜짐 정도(0~1)다.
	void Update(float DeltaTime, FMinimalViewInfo& InOutPOV, float Alpha = 1.0f);

	bool IsShakeActive(FCameraShakeHandle Handle) const;
	int32 GetActiveShakeCount() const { return mActiveShakes.Num(); }

	// 월드 쉐이크의 거리 감쇠 (UGameplayStatics::PlayWorldCameraShake 대응).
	// Inner 안이면 1, Outer 밖이면 0, 사이는 pow(1 - t, Falloff)다. Outer <= Inner이면 항상 1이다.
	static float CalcRadialShakeScale(const FVector& Epicenter, const FVector& CameraLocation,
		float InnerRadius, float OuterRadius, float Falloff = 1.0f);

private:
	struct FActiveShake {
		FCameraShakeHandle Handle{ InvalidCameraShakeHandle };
		std::unique_ptr<FCameraShakeBase> Shake;
	};

	FActiveShake* FindShake(FCameraShakeHandle Handle);
	const FActiveShake* FindShake(FCameraShakeHandle Handle) const;

private:
	TArray<FActiveShake> mActiveShakes;
	FCameraShakeHandle mNextHandle{ 1 };
};
