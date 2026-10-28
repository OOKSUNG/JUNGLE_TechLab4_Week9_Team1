#pragma once

#include <type_traits>

#include "Camera/CameraModifier.h"
#include "Camera/MinimalViewInfo.h"
#include "GameFramework/Actor.h"

class UCameraComponent;

class APlayerCameraManager : public AActor {
	DECLARE_CLASS(APlayerCameraManager, AActor)

public:
	APlayerCameraManager() = default;
	~APlayerCameraManager() override;
	APlayerCameraManager(const APlayerCameraManager& Other) = delete;
	APlayerCameraManager& operator=(const APlayerCameraManager& Other) = delete;
	APlayerCameraManager(APlayerCameraManager&& Other) = delete;
	APlayerCameraManager& operator=(APlayerCameraManager&& Other) = delete;

public:
	bool SetViewTarget(AActor* Target);
	bool SetViewTargetWithBlend(AActor* Target, float BlendTime);
	bool SetViewTargetCamera(UCameraComponent* Camera, float BlendTime = 0.0f);
	AActor* GetViewTarget() const;
	UCameraComponent* GetViewTargetCamera() const;
	void ResetViewTarget(UCameraComponent* Camera);
	void UpdateCamera(float DeltaTime);
	bool HasValidCameraView() const;
	const FMinimalViewInfo& GetCameraView() const;
	UCameraModifier* AddCameraModifier(UClass* ModifierClass);
	template <typename T>
	T* AddCameraModifier();
	UCameraModifier* FindCameraModifierByClass(const UClass* ModifierClass) const;
	bool RemoveCameraModifier(UCameraModifier* Modifier);
	void RemoveAllCameraModifiers();

private:
	static UCameraComponent* FindCameraComponent(AActor* Target);
	static bool CompareModifierPriority(const UCameraModifier* Left, const UCameraModifier* Right);
	void ApplyCameraModifiers(float DeltaTime, FMinimalViewInfo& InOutView);
	void FlushRemovedModifiers();

private:
	UCameraComponent* mViewTargetCamera{};
	FMinimalViewInfo mBaseCameraView{};
	FMinimalViewInfo mCameraView{};
	FMinimalViewInfo mBlendSourceView{};
	float mBlendDuration{};
	float mBlendElapsed{};
	bool mHasValidCameraView{};
	bool mApplyingModifiers{};
	TArray<UCameraModifier*> mModifiers{};
	TArray<UCameraModifier*> mRemovedModifiers{};
};

template <typename T>
T* APlayerCameraManager::AddCameraModifier() {
	static_assert(std::is_base_of_v<UCameraModifier, T>);
	return static_cast<T*>(AddCameraModifier(T::StaticClass()));
}
