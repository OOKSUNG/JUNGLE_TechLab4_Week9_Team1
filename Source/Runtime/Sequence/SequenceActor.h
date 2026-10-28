#pragma once

#include "GameFramework/Actor.h"
#include "SequencePlayer.h"

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
	void Play() { SequencePlayer.Play(); }
	void Pause() { SequencePlayer.Pause(); }
	void Stop() { SequencePlayer.Stop(); }

	bool bAutoPlay = false;

private:
	FSequencePlayer SequencePlayer;
};
