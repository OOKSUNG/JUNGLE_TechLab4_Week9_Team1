#include "EnginePCH.h"
#include "CameraShakeBase.h"

FCameraShakeBase::FCameraShakeBase(std::unique_ptr<FCameraShakePattern> InRootPattern)
	: mRootPattern(std::move(InRootPattern)) {
}

void FCameraShakeBase::SetRootPattern(std::unique_ptr<FCameraShakePattern> InRootPattern) {
	mRootPattern = std::move(InRootPattern);
}

void FCameraShakeBase::StartShake(float InShakeScale, ECameraShakePlaySpace InPlaySpace, const FRotator& InUserPlaySpaceRot) {
	mShakeScale = InShakeScale;
	mPlaySpace = InPlaySpace;
	mUserPlaySpaceRot = InUserPlaySpaceRot;

	if (mRootPattern) {
		mRootPattern->StartShakePattern();
	}
}

void FCameraShakeBase::UpdateAndApplyCameraShake(float DeltaTime, float Alpha, FMinimalViewInfo& InOutPOV) {
	if (!mRootPattern || mRootPattern->IsFinished()) {
		return;
	}

	FCameraShakeUpdateParams Params{};
	Params.DeltaTime = DeltaTime;
	Params.POV = InOutPOV;

	FCameraShakeUpdateResult Result{};
	mRootPattern->UpdateShakePattern(Params, Result);

	ApplyResult(Result, Alpha * mShakeScale, mPlaySpace, mUserPlaySpaceRot, InOutPOV);
}

void FCameraShakeBase::StopShake(bool bImmediately) {
	if (mRootPattern) {
		mRootPattern->StopShakePattern(bImmediately);
	}
}

bool FCameraShakeBase::IsFinished() const {
	return !mRootPattern || mRootPattern->IsFinished();
}

void FCameraShakeBase::ApplyResult(const FCameraShakeUpdateResult& InResult, float Scale,
	ECameraShakePlaySpace PlaySpace, const FRotator& UserPlaySpaceRot, FMinimalViewInfo& InOutPOV) {
	if (Scale == 0.0f) {
		return;
	}

	FCameraShakeUpdateResult Result{ InResult };
	Result.ApplyScale(Scale);

	const FQuat CameraQuat{ InOutPOV.Rotation.Quaternion() };
	const FQuat ShakeQuat{ Result.Rotation.Quaternion() };

	switch (PlaySpace) {
	case ECameraShakePlaySpace::CameraLocal:
		// 위치는 카메라 축으로 옮기고, 회전은 카메라 로컬에서 덧붙인다.
		InOutPOV.Location += CameraQuat.RotateVector(Result.Location);
		InOutPOV.Rotation = (CameraQuat * ShakeQuat).ToFRotator();
		break;

	case ECameraShakePlaySpace::World:
		InOutPOV.Location += Result.Location;
		InOutPOV.Rotation = (ShakeQuat * CameraQuat).ToFRotator();
		break;

	case ECameraShakePlaySpace::UserDefined: {
		// 사용자 공간에서의 흔들림을 월드로 옮긴 뒤(U * S * U⁻¹) 카메라 앞에 곱한다.
		const FQuat UserQuat{ UserPlaySpaceRot.Quaternion() };
		InOutPOV.Location += UserQuat.RotateVector(Result.Location);
		const FQuat WorldShake{ UserQuat * ShakeQuat * UserQuat.Inverse() };
		InOutPOV.Rotation = (WorldShake * CameraQuat).ToFRotator();
		break;
	}
	}

	InOutPOV.FOV += Result.FOV;
}
