#include "EnginePCH.h"
#include "Camera/PlayerCameraManager.h"
#include "Camera/CameraComponent.h"

#include <algorithm>

APlayerCameraManager::~APlayerCameraManager() {
	RemoveAllCameraModifiers();
	FlushRemovedModifiers();
}

bool APlayerCameraManager::SetViewTarget(AActor* Target) {
	return SetViewTargetWithBlend(Target, 0.0f);
}

bool APlayerCameraManager::SetViewTargetWithBlend(AActor* Target, float BlendTime) {
	UCameraComponent* Camera{ FindCameraComponent(Target) };
	return (!Target || Camera) && SetViewTargetCamera(Camera, BlendTime);
}

bool APlayerCameraManager::SetViewTargetCamera(UCameraComponent* Camera, float BlendTime) {
	if (Camera && (!Camera->IsRegistered() || Camera->GetWorld() != GetWorld() || !Camera->GetOwner() || Camera->GetOwner()->IsActorBeingDestroyed())) {
		return false;
	}
	if (Camera && Camera == mViewTargetCamera) {
		return true;
	}

	mBlendSourceView = mBaseCameraView;
	mBlendDuration = Camera && mHasValidCameraView ? std::max(BlendTime, 0.0f) : 0.0f;
	mBlendElapsed = 0.0f;
	mViewTargetCamera = Camera;
	if (!Camera) {
		mHasValidCameraView = false;
		mBaseCameraView = FMinimalViewInfo{};
		mCameraView = FMinimalViewInfo{};
		return true;
	}

	if (mBlendDuration <= 0.0f) {
		Camera->GetCameraView(mBaseCameraView);
		mCameraView = mBaseCameraView;
	}
	mHasValidCameraView = true;
	return true;
}

AActor* APlayerCameraManager::GetViewTarget() const {
	return mViewTargetCamera ? mViewTargetCamera->GetOwner() : nullptr;
}

UCameraComponent* APlayerCameraManager::GetViewTargetCamera() const {
	return mViewTargetCamera;
}

void APlayerCameraManager::ResetViewTarget(UCameraComponent* Camera) {
	if (mViewTargetCamera == Camera) {
		SetViewTargetCamera(nullptr);
	}
}

void APlayerCameraManager::UpdateCamera(float DeltaTime) {
	if (mApplyingModifiers || !mViewTargetCamera) {
		return;
	}

	const float CameraDeltaTime{ std::max(DeltaTime, 0.0f) };
	mViewTargetCamera->GetCameraView(mBaseCameraView);
	if (mBlendDuration > 0.0f) {
		mBlendElapsed = std::min(mBlendElapsed + CameraDeltaTime, mBlendDuration);
		const FMinimalViewInfo TargetView{ mBaseCameraView };
		mBaseCameraView = mBlendSourceView;
		mBaseCameraView.BlendViewInfo(TargetView, mBlendElapsed / mBlendDuration);
		if (mBlendElapsed >= mBlendDuration) {
			mBlendDuration = 0.0f;
		}
	}

	FMinimalViewInfo FinalView{ mBaseCameraView };
	ApplyCameraModifiers(CameraDeltaTime, FinalView);
	if (mHasValidCameraView) {
		mCameraView = FinalView;
	}
}

bool APlayerCameraManager::HasValidCameraView() const {
	return mHasValidCameraView;
}

const FMinimalViewInfo& APlayerCameraManager::GetCameraView() const {
	return mCameraView;
}

UCameraModifier* APlayerCameraManager::AddCameraModifier(UClass* ModifierClass) {
	if (!ModifierClass || !ModifierClass->IsChildOf(UCameraModifier::StaticClass()) || !ModifierClass->Constructor) {
		return nullptr;
	}
	UCameraModifier* Modifier{ NewObject<UCameraModifier>(this, ModifierClass, NAME_None, EObjectFlags::RF_Transient) };
	if (Modifier) {
		Modifier->mCameraOwner = this;
		mModifiers.Add(Modifier);
	}
	return Modifier;
}

UCameraModifier* APlayerCameraManager::FindCameraModifierByClass(const UClass* ModifierClass) const {
	if (!ModifierClass) {
		return nullptr;
	}
	for (UCameraModifier* Modifier : mModifiers) {
		if (Modifier->IsA(ModifierClass)) {
			return Modifier;
		}
	}
	return nullptr;
}

bool APlayerCameraManager::RemoveCameraModifier(UCameraModifier* Modifier) {
	const int32 Index{ mModifiers.Find(Modifier) };
	if (Index == INDEX_NONE) {
		return false;
	}
	mModifiers.RemoveAt(static_cast<uint32>(Index));
	Modifier->mCameraOwner = nullptr;
	mRemovedModifiers.Add(Modifier);
	if (!mApplyingModifiers) {
		FlushRemovedModifiers();
	}
	return true;
}

void APlayerCameraManager::RemoveAllCameraModifiers() {
	while (!mModifiers.IsEmpty()) {
		RemoveCameraModifier(mModifiers[mModifiers.Num() - 1]);
	}
}

UCameraComponent* APlayerCameraManager::FindCameraComponent(AActor* Target) {
	if (!Target || Target->IsActorBeingDestroyed()) {
		return nullptr;
	}
	for (UActorComponent* Component : Target->GetComponents()) {
		UCameraComponent* Camera{ Cast<UCameraComponent>(Component) };
		if (Camera && Camera->IsRegistered()) {
			return Camera;
		}
	}
	return nullptr;
}

bool APlayerCameraManager::CompareModifierPriority(const UCameraModifier* Left, const UCameraModifier* Right) {
	return Left->GetPriority() < Right->GetPriority();
}

void APlayerCameraManager::ApplyCameraModifiers(float DeltaTime, FMinimalViewInfo& InOutView) {
	mApplyingModifiers = true;
	TArray<UCameraModifier*> Modifiers{ mModifiers };
	std::stable_sort(Modifiers.begin(), Modifiers.end(), &CompareModifierPriority);
	for (UCameraModifier* Modifier : Modifiers) {
		Modifier->UpdateAlpha(DeltaTime);
	}
	for (UCameraModifier* Modifier : Modifiers) {
		if (mModifiers.Find(Modifier) == INDEX_NONE || Modifier->GetAlpha() <= 0.0f) {
			continue;
		}
		FMinimalViewInfo ModifiedView{ InOutView };
		const bool StopModifiers{ Modifier->ModifyCamera(DeltaTime, ModifiedView) };
		InOutView.BlendViewInfo(ModifiedView, Modifier->GetAlpha());
		if (StopModifiers) {
			break;
		}
	}
	mApplyingModifiers = false;
	FlushRemovedModifiers();
}

void APlayerCameraManager::FlushRemovedModifiers() {
	for (UCameraModifier* Modifier : mRemovedModifiers) {
		delete Modifier;
	}
	mRemovedModifiers.Reset();
}
