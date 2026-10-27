#pragma once

#include "Core/Types.h"
#include "Core/EngineString.h"
#include "Math/EngineMath.h"
#include "Math/Color.h"
#include <variant>
#include <vector>
#include <limits>

struct CameraKey // KeyFrame에서의 Camera 정보
{
	FVector Location;
	FRotator Rotation;
	float FieldOfView = 60.0f;
};

struct FadeKey // 첫 번째 키와 두 번째 키의 Alpha
{
	float StartAlpha = 0.0f;
	float EndAlpha = 0.0f;
};

struct FCameraSection
{
	int32 KeyFrames[2] = {};
	int KeyCount = 0;
	CameraKey KeyCam[2] = {};
};

struct FFadeSection
{
	int32 KeyFrames[2] = {};
	int KeyCount = 0;
	FadeKey KeyFade;
};

struct FCameraTimelineTrack
{
	std::vector<FCameraSection> CamSections;
};

struct FFadeTimelineTrack
{
	std::vector<FFadeSection> FadeSections;
};

struct FTimelineTrack
{
	FString Name;
	FLinearColor Color;
	std::variant<FCameraTimelineTrack, FFadeTimelineTrack> Rows;
};

// Sequence UI에서 값을 가져오기 위한 Data
struct FSequenceData
{
	std::vector<FTimelineTrack> Rows = {
		{ "Viewport Camera", FLinearColor(0.31f, 0.59f, 0.90f, 0.30f), FCameraTimelineTrack{} },
		{ "Fade", FLinearColor(0.59f, 0.43f, 0.82f, 0.30f), FFadeTimelineTrack{} }
	};
	int32 StartFrame = 0;
	int32 EndFrameSecond = 100;
	int PlaybackFPS = 30;

	int32 GetEndFrame() const
	{
		const int64 End = static_cast<int64>(StartFrame) + static_cast<int64>(EndFrameSecond) * PlaybackFPS;
		return static_cast<int32>(FMath::Clamp<int64>(End, StartFrame, std::numeric_limits<int32>::max()));
	}
};
