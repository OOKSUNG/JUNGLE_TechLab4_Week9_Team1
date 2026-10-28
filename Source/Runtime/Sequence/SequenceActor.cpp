#include "EnginePCH.h"
#include "SequenceActor.h"
#include "Components/SceneComponent.h"
#include "Camera/PlayerCameraManager.h"
#include "Camera/CameraComponent.h"
#include "Engine/World.h"
#include "Engine/Level.h"

ASequenceActor::ASequenceActor()
{
	SetRootComponent(CreateDefaultSubobject<USceneComponent>("SequenceRoot"));
	PrimaryActorTick.bCanEverTick = true;
	// 일반 이동/카메라 입력 이후, World의 CameraManager 갱신 이전에 최종 위치를 기록한다.
	PrimaryActorTick.TickGroup = ETickingGroup::PostUpdateWork;
}

void ASequenceActor::BeginPlay()	// bAutoPlay true 시 시작할때 Sequence가 시작됨
{
	Super::BeginPlay();
	Stop();
	if (bAutoPlay) Play();
}

void ASequenceActor::Tick(float DeltaTime)
{
	const bool bWasPlaying = SequencePlayer.IsPlaying();
	SequencePlayer.Tick(DeltaTime);
	if (SequencePlayer.IsStopped() || (SequencePlayer.HasFinished() && !bWasPlaying))
	{
		ReleaseCameraView();
		return;
	}

	// Player를 직접 Play한 경우도 지원한다. 시간은 Actor에서 한 번만 진행시킨다.
	if (bWasPlaying || bCameraPlaybackActive)
	{
		ApplyCameraView();
	}
	// 끝 프레임에 도달한 Tick에서는 마지막 값을 적용하고, 다음 Tick에서 기본 카메라로 복귀한다.
}

void ASequenceActor::Play()
{
	SequencePlayer.Play();
	ApplyCameraView();
}

void ASequenceActor::Stop()
{
	SequencePlayer.Stop();
	ReleaseCameraView();
}

void ASequenceActor::ApplyCameraView()
{
	UWorld* World = GetWorld();
	// 에디터 패널에서의 재생은 기존처럼 시간/값 확인용이다. 게임 월드의 카메라에만 전달한다.
	if (!World || (World->GetWorldType() != EWorldType::Game && World->GetWorldType() != EWorldType::PIE))
		return;
	CameraKey Key{};
	const bool bHasCamera = SequencePlayer.GetCurrentCameraKey(Key);
	if (!bHasCamera)
	{
		// 구간 밖에서는 원래 시점과 입력을 복원한다. Fade만 있는 연출은 카메라를 건드리지 않는다.
		ReleaseCameraView();
		return;
	}
	APlayerCameraManager* Manager = World->GetPlayerCameraManager();
	UCameraComponent* Camera = Manager ? Manager->GetViewTargetCamera() : nullptr;
	if (!Camera || !Camera->IsRegistered() || !Camera->GetOwner() || Camera->GetOwner()->IsActorBeingDestroyed())
	{
		ReleaseCameraView();
		return;
	}
	if (ControlledCameraUUID != Camera->GetUUID())
	{
		ReleaseCameraView();
		AcquireCamera(Camera);
	}
	// 입력용 Component Tick을 막는다. PIE의 포커스 코드가 ExternalInputManaged를 바꿔도 유지된다.
	Camera->PrimaryComponentTick.SetTickFunctionEnable(false);
	// 기록된 키는 월드 좌표이므로 부모가 있는 카메라도 월드 좌표 설정 함수를 사용한다.
	Camera->SetWorldLocationAndRotation(Key.Location, Key.Rotation, false);
	Camera->SetFieldOfView(Key.FieldOfView);
}

void ASequenceActor::AcquireCamera(UCameraComponent* Camera)
{
	// 같은 카메라를 두 Sequence가 동시에 쓰지 않게 한다. 이전 연출을 복원한 뒤 새 상태를 저장한다.
	for (AActor* Actor : GetWorld()->GetPersistentLevel()->GetActors())
	{
		if (auto* Other = Cast<ASequenceActor>(Actor); Other && Other != this && Other->ControlledCameraUUID == Camera->GetUUID())
			Other->Stop();
	}
	ControlledCameraUUID = Camera->GetUUID();
	SavedCameraRelativeState.Location = Camera->GetRelativeLocation();
	SavedCameraRelativeState.Rotation = Camera->GetRelativeRotation();
	SavedCameraRelativeState.FieldOfView = Camera->GetFieldOfView();
	bSavedCameraTickEnabled = Camera->PrimaryComponentTick.IsTickFunctionRegistered()
		? Camera->PrimaryComponentTick.IsTickFunctionEnabled()
		: Camera->PrimaryComponentTick.bStartWithTickEnabled;
	bCameraPlaybackActive = true;
}

void ASequenceActor::ReleaseCameraView()
{
	// 카메라가 삭제되거나 씬이 바뀌었을 수 있으므로 보관한 포인터를 역참조하지 않고 식별자로 찾는다.
	if (ControlledCameraUUID)
	{
		for (UObject* Object : GUObjectArray)
		{
			if (Object && Object->GetUUID() == ControlledCameraUUID)
			{
				if (auto* Camera = Cast<UCameraComponent>(Object))
				{
					Camera->SetRelativeLocationAndRotation(SavedCameraRelativeState.Location, SavedCameraRelativeState.Rotation);
					Camera->SetFieldOfView(SavedCameraRelativeState.FieldOfView);
					Camera->PrimaryComponentTick.SetTickFunctionEnable(bSavedCameraTickEnabled);
				}
				break;
			}
		}
	}
	ControlledCameraUUID = 0;
	bCameraPlaybackActive = false;
}

void ASequenceActor::EndPlay()
{
	Stop();
	Super::EndPlay();
}

void ASequenceActor::Serialize(FStructuredArchive::FRecord Record)
{
	Super::Serialize(Record);
	FSequenceData Data = SequencePlayer.GetSequenceData();
	Data.Serialize(Record.EnterRecord("Sequence"));
	if (Record.GetUnderlyingArchive().IsLoading() && !Record.GetUnderlyingArchive().IsError())
	{
		ReleaseCameraView();
		SequencePlayer.SetSequenceData(Data);
	}
}
