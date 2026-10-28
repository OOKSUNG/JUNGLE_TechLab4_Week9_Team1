#include "EnginePCH.h"
#include "SequencePlayer.h"
#include "Math/FInterpEaseInOut.h"
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
	bFinished = false;
	Pause();
}

void FSequencePlayer::Play()
{
	if (PlaybackFrame >= SequenceData.GetEndFrame())
		PlaybackFrame = static_cast<float>(SequenceData.StartFrame);
	bIsPlaying = true;
	bPlaybackStarted = true;
	bFinished = false;
}

void FSequencePlayer::Stop()
{
	Pause();
	bPlaybackStarted = false;
	bFinished = false;
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
	{
		Pause();
		bFinished = true;
	}
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
		float Playratio = (PlaybackFrame - Section->KeyFrames[0]) / (static_cast<float>(Section->KeyFrames[1]) - Section->KeyFrames[0]);
		if (Section->Curve == CurveType::Linear)
		{
			OutCamera.Location.X = std::lerp(Section->KeyCam[0].Location.X, Section->KeyCam[1].Location.X, Playratio);
			OutCamera.Location.Y = std::lerp(Section->KeyCam[0].Location.Y, Section->KeyCam[1].Location.Y, Playratio);
			OutCamera.Location.Z = std::lerp(Section->KeyCam[0].Location.Z, Section->KeyCam[1].Location.Z, Playratio);
			OutCamera.Rotation.Pitch = std::lerp(Section->KeyCam[0].Rotation.Pitch, Section->KeyCam[1].Rotation.Pitch, Playratio);
			OutCamera.Rotation.Yaw = std::lerp(Section->KeyCam[0].Rotation.Yaw, Section->KeyCam[1].Rotation.Yaw, Playratio);
			OutCamera.Rotation.Roll = std::lerp(Section->KeyCam[0].Rotation.Roll, Section->KeyCam[1].Rotation.Roll, Playratio);
			OutCamera.FieldOfView = std::lerp(Section->KeyCam[0].FieldOfView, Section->KeyCam[1].FieldOfView, Playratio);
			return true;
		}

		if (Section->Curve == CurveType::EaseIn || Section->Curve == CurveType::EaseOut)
		{
			Playratio = Section->Curve == CurveType::EaseIn ? InterpEaseIn(0.0f, 1.0f, Playratio, Section->EaseExp): InterpEaseOut(0.0f, 1.0f, Playratio, Section->EaseExp);
			OutCamera.Location.X = std::lerp(Section->KeyCam[0].Location.X, Section->KeyCam[1].Location.X, Playratio);
			OutCamera.Location.Y = std::lerp(Section->KeyCam[0].Location.Y, Section->KeyCam[1].Location.Y, Playratio);
			OutCamera.Location.Z = std::lerp(Section->KeyCam[0].Location.Z, Section->KeyCam[1].Location.Z, Playratio);
			OutCamera.Rotation.Pitch = std::lerp(Section->KeyCam[0].Rotation.Pitch, Section->KeyCam[1].Rotation.Pitch, Playratio);
			OutCamera.Rotation.Yaw = std::lerp(Section->KeyCam[0].Rotation.Yaw, Section->KeyCam[1].Rotation.Yaw, Playratio);
			OutCamera.Rotation.Roll = std::lerp(Section->KeyCam[0].Rotation.Roll, Section->KeyCam[1].Rotation.Roll, Playratio);
			OutCamera.FieldOfView = std::lerp(Section->KeyCam[0].FieldOfView, Section->KeyCam[1].FieldOfView, Playratio);
			return true;
		}

		if (Section->Curve == CurveType::Bezier)
		{
			OutCamera.Location.X = std::lerp(Section->KeyCam[0].Location.X, Section->KeyCam[1].Location.X, Playratio);
			OutCamera.Location.Y = std::lerp(Section->KeyCam[0].Location.Y, Section->KeyCam[1].Location.Y, Playratio);
			OutCamera.Location.Z = std::lerp(Section->KeyCam[0].Location.Z, Section->KeyCam[1].Location.Z, Playratio);
			OutCamera.Rotation.Pitch = std::lerp(Section->KeyCam[0].Rotation.Pitch, Section->KeyCam[1].Rotation.Pitch, Playratio);
			OutCamera.Rotation.Yaw = std::lerp(Section->KeyCam[0].Rotation.Yaw, Section->KeyCam[1].Rotation.Yaw, Playratio);
			OutCamera.Rotation.Roll = std::lerp(Section->KeyCam[0].Rotation.Roll, Section->KeyCam[1].Rotation.Roll, Playratio);
			OutCamera.FieldOfView = std::lerp(Section->KeyCam[0].FieldOfView, Section->KeyCam[1].FieldOfView, Playratio);
			return true;
		}
		return false;
	}
	return false;
}

bool FSequencePlayer::GetCurrentFadeAlpha(float& OutAlpha) const
{
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

	float Playratio = (PlaybackFrame - ActiveSection->KeyFrames[0]) /
		(static_cast<float>(ActiveSection->KeyFrames[1]) - ActiveSection->KeyFrames[0]);
	switch (ActiveSection->Curve)
	{
	case CurveType::Linear:
	case CurveType::Bezier:
		break;
	case CurveType::EaseIn:
		Playratio = InterpEaseIn(0.0f, 1.0f, Playratio, ActiveSection->EaseExp);
		break;
	case CurveType::EaseOut:
		Playratio = InterpEaseOut(0.0f, 1.0f, Playratio, ActiveSection->EaseExp);
		break;
	default:
		return false;
	}
	OutAlpha = std::lerp(ActiveSection->KeyFade.StartAlpha, ActiveSection->KeyFade.EndAlpha, Playratio);
	return true;
}

