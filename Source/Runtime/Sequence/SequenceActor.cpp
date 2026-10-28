#include "EnginePCH.h"
#include "SequenceActor.h"
#include "Components/SceneComponent.h"

ASequenceActor::ASequenceActor()
{
	SetRootComponent(CreateDefaultSubobject<USceneComponent>("SequenceRoot"));
	PrimaryActorTick.bCanEverTick = true;
}

void ASequenceActor::BeginPlay()	// bAutoPlay true 시 시작할때 Sequence가 시작됨
{
	Super::BeginPlay();
	SequencePlayer.Stop();
	if (bAutoPlay) SequencePlayer.Play();
}

void ASequenceActor::Tick(float DeltaTime)
{
	SequencePlayer.Tick(DeltaTime);
}

void ASequenceActor::EndPlay()
{
	SequencePlayer.Stop();
	Super::EndPlay();
}

void ASequenceActor::Serialize(FStructuredArchive::FRecord Record)
{
	Super::Serialize(Record);
	FSequenceData Data = SequencePlayer.GetSequenceData();
	Data.Serialize(Record.EnterRecord("Sequence"));
	if (Record.GetUnderlyingArchive().IsLoading() && !Record.GetUnderlyingArchive().IsError())
		SequencePlayer.SetSequenceData(Data);
}
