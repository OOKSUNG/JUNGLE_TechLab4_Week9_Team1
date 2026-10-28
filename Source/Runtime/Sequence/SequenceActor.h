#pragma once

#include "GameFramework/Actor.h"
#include "SequencePlayer.h"

class UCameraComponent;

class ASequenceActor : public AActor
{
	DECLARE_CLASS(ASequenceActor, AActor)
	REFLECT_START(ASequenceActor)
		PROPERTY(bAutoPlay)
	REFLECT_END()

public:
	ASequenceActor();
	void BeginPlay() override;
	void Tick(float DeltaTime) override;
	void EndPlay() override;
	using Super::Serialize;
	void Serialize(FStructuredArchive::FRecord Record) override;

	FSequencePlayer& GetSequencePlayer() { return SequencePlayer; }
	const FSequencePlayer& GetSequencePlayer() const { return SequencePlayer; }
	void Play();
	void Pause() { SequencePlayer.Pause(); }
	void Stop();
	// 해당 게임 월드에서 재생을 시작한 Sequence의 현재 Fade 값. Stop 시에는 제외한다.
	static float GetWorldFadeAlpha(UWorld* World);

	bool bAutoPlay = false;

private:
	void ApplyCameraView();
	void AcquireCamera(UCameraComponent* Camera);
	void ReleaseCameraView();

	FSequencePlayer SequencePlayer;
	bool bCameraPlaybackActive = false;
	uint32 ControlledCameraUUID = 0;
	// 카메라 부모가 있는 경우에도 원래 배치를 복원할 수 있도록 상대 좌표로 보관한다.
	CameraKey SavedCameraRelativeState{};
	bool bSavedCameraTickEnabled = false;
};
