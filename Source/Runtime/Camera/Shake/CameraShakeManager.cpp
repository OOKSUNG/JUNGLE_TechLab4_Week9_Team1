#include "EnginePCH.h"
#include "CameraShakeManager.h"

FCameraShakeHandle FCameraShakeManager::AddShake(std::unique_ptr<FCameraShakeBase> Shake, float Scale,
	ECameraShakePlaySpace PlaySpace, const FRotator& UserPlaySpaceRot) {
	if (!Shake || Scale <= 0.0f) {
		return InvalidCameraShakeHandle;
	}

	if (Shake->bSingleInstance) {
		for (FActiveShake& Active : mActiveShakes) {
			if (Active.Shake->bSingleInstance && Active.Shake->Name == Shake->Name) {
				Active.Shake->StartShake(Scale, PlaySpace, UserPlaySpaceRot);
				return Active.Handle;
			}
		}
	}

	Shake->StartShake(Scale, PlaySpace, UserPlaySpaceRot);

	const FCameraShakeHandle Handle{ mNextHandle++ };
	if (mNextHandle == InvalidCameraShakeHandle) {
		mNextHandle = 1;
	}
	mActiveShakes.Emplace(FActiveShake{ Handle, std::move(Shake) });
	return Handle;
}

void FCameraShakeManager::RemoveShake(FCameraShakeHandle Handle, bool bImmediately) {
	if (FActiveShake* Active{ FindShake(Handle) }) {
		Active->Shake->StopShake(bImmediately);
	}
}

void FCameraShakeManager::RemoveAllShakesByName(const FString& Name, bool bImmediately) {
	for (FActiveShake& Active : mActiveShakes) {
		if (Active.Shake->Name == Name) {
			Active.Shake->StopShake(bImmediately);
		}
	}
}

void FCameraShakeManager::RemoveAllShakes(bool bImmediately) {
	for (FActiveShake& Active : mActiveShakes) {
		Active.Shake->StopShake(bImmediately);
	}
}

void FCameraShakeManager::Update(float DeltaTime, FMinimalViewInfo& InOutPOV, float Alpha) {
	// 언리얼과 같이 앞 쉐이크가 바꾼 POV 위에 다음 쉐이크를 차례로 누적한다.
	for (FActiveShake& Active : mActiveShakes) {
		Active.Shake->UpdateAndApplyCameraShake(DeltaTime, Alpha, InOutPOV);
	}

	// 즉시 Stop된 쉐이크도 여기서 정리된다. 뒤에서부터 지워 인덱스가 밀리지 않게 한다.
	for (int32 Index{ mActiveShakes.Num() - 1 }; Index >= 0; --Index) {
		if (mActiveShakes[static_cast<uint32>(Index)].Shake->IsFinished()) {
			mActiveShakes.RemoveAt(static_cast<uint32>(Index));
		}
	}
}

bool FCameraShakeManager::IsShakeActive(FCameraShakeHandle Handle) const {
	const FActiveShake* Active{ FindShake(Handle) };
	return Active && !Active->Shake->IsFinished();
}

float FCameraShakeManager::CalcRadialShakeScale(const FVector& Epicenter, const FVector& CameraLocation,
	float InnerRadius, float OuterRadius, float Falloff) {
	if (OuterRadius <= InnerRadius) {
		return 1.0f;
	}

	const float Distance{ FVector::Distance(Epicenter, CameraLocation) };
	const float DistancePct{ FMath::Clamp((Distance - InnerRadius) / (OuterRadius - InnerRadius), 0.0f, 1.0f) };
	return std::pow(1.0f - DistancePct, Falloff);
}

FCameraShakeManager::FActiveShake* FCameraShakeManager::FindShake(FCameraShakeHandle Handle) {
	for (FActiveShake& Active : mActiveShakes) {
		if (Active.Handle == Handle) {
			return &Active;
		}
	}
	return nullptr;
}

const FCameraShakeManager::FActiveShake* FCameraShakeManager::FindShake(FCameraShakeHandle Handle) const {
	for (const FActiveShake& Active : mActiveShakes) {
		if (Active.Handle == Handle) {
			return &Active;
		}
	}
	return nullptr;
}
