#pragma once

#include "SequenceData.h"

class FSequencePlayer
{
public:
	void SetSequenceData(const FSequenceData& InData);	// Preview의 SequenceData 세팅용
	const FSequenceData& GetSequenceData() const { return SequenceData; }	
	FSequenceData& GetSequenceData() { return SequenceData; }

	void Play();
	void Pause() { bIsPlaying = false; }
	void Stop();
	void Tick(float DeltaTime);
	bool IsPlaying() const { return bIsPlaying; }
	float GetPlaybackFrame() const { return PlaybackFrame; }
	void SetPlaybackFrame(float InFrame);
	void SetPlaybackSettings(int InFPS, int32 InDurationSeconds);

	bool GetCurrentCameraKey(CameraKey& OutCamera) const;	// 현재 PlaybackFrame의 Camera 정보를 가져옴 
	bool GetCurrentFadeAlpha(float& OutAlpha) const;	// 현재 PlaybackFrame의 Alpha를 가져옴 

private:
	FSequenceData SequenceData;
	float PlaybackFrame = 0.0f;
	bool bIsPlaying = false;
};
