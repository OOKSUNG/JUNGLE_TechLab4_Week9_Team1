#include "EnginePCH.h"
#include "SequencePlayer.h"
#include <cmath>
#include <limits>

namespace
{
	bool IsSectionActive(float Frame, const int32 (&KeyFrames)[2], int KeyCount)
	{
		if (KeyCount != 2 || KeyFrames[0] == KeyFrames[1] || !std::isfinite(Frame))
			return false;
		return Frame >= FMath::Min(KeyFrames[0], KeyFrames[1]) &&
			Frame <= FMath::Max(KeyFrames[0], KeyFrames[1]);
	}
}

void FSequencePlayer::SetSequenceData(const FSequenceData& InData)
{
	SequenceData = InData;
	SequenceData.StartFrame = FMath::Clamp(SequenceData.StartFrame, 0, std::numeric_limits<int32>::max() - 1);
	SetPlaybackSettings(SequenceData.PlaybackFPS, SequenceData.EndFrameSecond);
	Stop();
}

void FSequencePlayer::SetPlaybackSettings(int InFPS, int32 InDurationSeconds)
{
	SequenceData.StartFrame = FMath::Clamp(SequenceData.StartFrame, 0, std::numeric_limits<int32>::max() - 1);
	const int32 AvailableFrames = std::numeric_limits<int32>::max() - SequenceData.StartFrame;
	SequenceData.PlaybackFPS = FMath::Clamp(InFPS, 1, AvailableFrames);
	const int32 MaxSeconds = AvailableFrames / SequenceData.PlaybackFPS;
	SequenceData.EndFrameSecond = FMath::Clamp(InDurationSeconds, 1, MaxSeconds);
	SetPlaybackFrame(PlaybackFrame);
}

void FSequencePlayer::SetPlaybackFrame(float InFrame)
{
	if (!std::isfinite(InFrame))
		return;
	PlaybackFrame = FMath::Clamp(InFrame, static_cast<float>(SequenceData.StartFrame),
		static_cast<float>(SequenceData.GetEndFrame()));
	Pause();
}

void FSequencePlayer::Play()
{
	if (PlaybackFrame >= SequenceData.GetEndFrame())
		PlaybackFrame = static_cast<float>(SequenceData.StartFrame);
	bIsPlaying = true;
}

void FSequencePlayer::Stop()
{
	Pause();
	PlaybackFrame = static_cast<float>(SequenceData.StartFrame);
}

void FSequencePlayer::Tick(float DeltaTime)
{
	if (!bIsPlaying || !std::isfinite(DeltaTime) || DeltaTime <= 0.0f)
		return;
	const double NextFrame = static_cast<double>(PlaybackFrame) + static_cast<double>(DeltaTime) * SequenceData.PlaybackFPS;
	const int32 EndFrame = SequenceData.GetEndFrame();
	PlaybackFrame = static_cast<float>(FMath::Min(NextFrame, static_cast<double>(EndFrame)));
	if (NextFrame >= EndFrame)
		Pause();
}

bool FSequencePlayer::GetCurrentCameraKey(CameraKey& OutCamera) const
{
	(void)OutCamera; // TODO 구현 전에는 출력값을 변경하지 않는다.
	const FCameraTimelineTrack* Track = nullptr;
	for (const auto& Row : SequenceData.Rows)
	{
		Track = std::get_if<FCameraTimelineTrack>(&Row.Rows);
		if (Track)
			break;
	}
	if (!Track)
		return false;

	for (auto Section = Track->CamSections.rbegin(); Section != Track->CamSections.rend(); ++Section)
	{
		if (!IsSectionActive(PlaybackFrame, Section->KeyFrames, Section->KeyCount))
			continue;

		// TODO: Section->KeyFrames와 PlaybackFrame으로 구간 내 현재 시점을 계산한다.
		// TODO: 선택할 보간 방식으로 Section->KeyCam[0], [1]의 위치/회전/FOV를 계산해 OutCamera에 넣는다.
		// TODO: OutCamera 계산이 완료되면 true를 반환한다.
		return false;
	}
	return false;
}

bool FSequencePlayer::GetCurrentFadeAlpha(float& OutAlpha) const
{
	(void)OutAlpha; // TODO 구현 전에는 출력값을 변경하지 않는다.
	const FFadeTimelineTrack* Track = nullptr;
	for (const auto& Row : SequenceData.Rows)
	{
		Track = std::get_if<FFadeTimelineTrack>(&Row.Rows);
		if (Track)
			break;
	}
	if (!Track)
		return false;

	const FFadeSection* ActiveSection = nullptr;
	for (auto Section = Track->FadeSections.rbegin(); Section != Track->FadeSections.rend(); ++Section)
	{
		if (!IsSectionActive(PlaybackFrame, Section->KeyFrames, Section->KeyCount))
			continue;

		if (!ActiveSection || FMath::Min(Section->KeyFrames[0], Section->KeyFrames[1]) >
			FMath::Min(ActiveSection->KeyFrames[0], ActiveSection->KeyFrames[1]))
		{
			ActiveSection = &*Section;
		}
	}
	if (!ActiveSection)
		return false;
	// TODO: ActiveSection->KeyFrames와 PlaybackFrame으로 구간 내 현재 시점을 계산한다.
	// TODO: 선택할 보간 방식으로 KeyFade.StartAlpha/EndAlpha의 현재 값을 계산해 OutAlpha에 넣는다.
	// TODO: OutAlpha 계산이 완료되면 true를 반환한다.
	return false;
}

