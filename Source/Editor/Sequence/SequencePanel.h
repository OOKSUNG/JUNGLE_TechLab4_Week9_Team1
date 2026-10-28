#pragma once

#include "EnginePCH.h"
#include "Editor/EditorUI/EditorPanel.h"
#include "ThirdParty/ImNeoSequencer/imgui_neo_sequencer.h"

#include "Sequence/SequencePlayer.h"
#include <functional>

class FSequencePanel : public IEditorPanel
{
public:	
	bool Init() override;
	void Tick(float DeltaTime) override;
	void OnRender() override;

	const FSequenceData& GetSequenceData() const { return PreviewPlayer.GetSequenceData(); }	// Sequencer UI에서 편집한 Data 값을 가져옴
	const FSequencePlayer& GetPreviewPlayer() const { return PreviewPlayer; }	// 편집용 Sequencer 객체 가져옴

	const char* GetPanelName() const override { return "Sequence"; }
	void SetViewportCameraProvider(std::function<bool(CameraKey&)> InProvider) { ViewportCameraProvider = std::move(InProvider); }	// 키 기록용 현재 뷰포트 카메라

private:

	static bool IsFadeLayoutValid(const FFadeTimelineTrack& Track);

	FSequencePlayer PreviewPlayer;
	std::function<bool(CameraKey&)> ViewportCameraProvider;

	int SelectedTrack = 0;
	float NewFadeKeyAlpha = 0.0f;
	float LastFadeValueFrame = 0.0f;
	bool bFadeValueEdited = false;
};
