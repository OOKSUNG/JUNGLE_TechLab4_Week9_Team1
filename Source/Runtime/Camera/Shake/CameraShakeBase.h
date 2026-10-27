#pragma once

#include <memory>
#include "CameraShakePattern.h"

// 쉐이크 하나의 재생 단위 (언리얼 UCameraShakeBase 대응).
// 루트 패턴을 소유하고, 재생 배율·PlaySpace를 적용해 결과를 POV에 합성한다.
class FCameraShakeBase {
public:
	FString Name;					// bSingleInstance 판정에 쓰는 프리셋 이름
	bool bSingleInstance{};			// true이면 같은 Name의 쉐이크를 새로 만들지 않고 재시작한다

public:
	FCameraShakeBase() = default;
	explicit FCameraShakeBase(std::unique_ptr<FCameraShakePattern> InRootPattern);

	void SetRootPattern(std::unique_ptr<FCameraShakePattern> InRootPattern);
	FCameraShakePattern* GetRootPattern() const { return mRootPattern.get(); }

	void StartShake(float InShakeScale = 1.0f,
		ECameraShakePlaySpace InPlaySpace = ECameraShakePlaySpace::CameraLocal,
		const FRotator& InUserPlaySpaceRot = FRotator{});

	// 패턴을 갱신하고 Alpha × ShakeScale을 곱해 InOutPOV에 합성한다.
	void UpdateAndApplyCameraShake(float DeltaTime, float Alpha, FMinimalViewInfo& InOutPOV);

	void StopShake(bool bImmediately = false);
	bool IsFinished() const;

	float GetShakeScale() const { return mShakeScale; }
	void SetShakeScale(float InScale) { mShakeScale = InScale; }

	// 패턴 결과를 POV에 합성한다. 외부에서 계산한 결과를 적용할 때도 쓸 수 있다.
	static void ApplyResult(const FCameraShakeUpdateResult& InResult, float Scale,
		ECameraShakePlaySpace PlaySpace, const FRotator& UserPlaySpaceRot, FMinimalViewInfo& InOutPOV);

private:
	std::unique_ptr<FCameraShakePattern> mRootPattern;

	float mShakeScale{ 1.0f };
	ECameraShakePlaySpace mPlaySpace{ ECameraShakePlaySpace::CameraLocal };
	FRotator mUserPlaySpaceRot{};
};
