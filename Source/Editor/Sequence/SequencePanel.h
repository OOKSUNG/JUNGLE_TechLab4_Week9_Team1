#pragma once

#include "EnginePCH.h"
#include "Editor/EditorUI/EditorPanel.h"
#include "ThirdParty/ImNeoSequencer/imgui_neo_sequencer.h"

#include <variant>

struct CameraKey	// KeyFrame에서의 Camera 정보
{
	FVector Location;
	FRotator Rotation;
};

struct FadeKey	// KeyFrame 구간 내에서의 Fade 정보
{
	float StartAlpha;
	float EndAlpha;
};

class FSequencePanel : public IEditorPanel
{
public:	
	bool Init() override;
	void Tick(float DeltaTime) override;
	void OnRender() override;

	const char* GetPanelName() const override { return "Sequence"; }

private:

	struct FCameraSection	// KeyFrame 구간 정보가 같이 담긴 Camera Section
	{
		int32 KeyFrames[2] = {};
		int KeyCount = 0;
		CameraKey KeyCam[2] = {};
	};

	struct FFadeSection		// KeyFrame 구간 정보가 같이 담긴 Fade Section
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

	struct FTimelineTrack	// 타임라인 한줄에 담긴 정보, Row의 경우 카메라 or Fade 효과냐에 따라 쓸 Row가 다르므로 Variant 사용
	{
		const char* Name;
		ImVec4 Color;
		std::variant<FCameraTimelineTrack, FFadeTimelineTrack> Rows;
	};


	FTimelineTrack Rows[3] = { // Row 기본세팅
		{ "Camera", ImVec4(0.31f, 0.59f, 0.90f, 0.30f), FCameraTimelineTrack{} },
		{ "Fade In", ImVec4(0.59f, 0.43f, 0.82f, 0.30f), FFadeTimelineTrack{} },
		{ "Fade Out", ImVec4(0.82f, 0.51f, 0.31f, 0.30f), FFadeTimelineTrack{} }
	};

	int32 StartFrame = 0;
	int32 EndFrameSecond = 100;
	int32 EndFrame = 0;
	int SelectedTrack = 0;
	float PlaybackFrame = 0;	// Play할때 시작하는 프레임값
	int PlaybackFPS = 30;	// Play 할때 사용할 FPS
	bool bIsPlaying = false;
};
