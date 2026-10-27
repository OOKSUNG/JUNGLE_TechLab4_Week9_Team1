#include "EnginePCH.h"
#include "SequencePanel.h"
#include <limits>

bool FSequencePanel::Init()
{
	EndFrame = StartFrame + EndFrameSecond * PlaybackFPS;
	return true;
}

void FSequencePanel::Tick(float DeltaTime)
{
	if (!bIsPlaying || DeltaTime <= 0.0f)
		return;

	PlaybackFrame += DeltaTime * PlaybackFPS;	// dt * PlaybackFPS만큼 전체 Frame에 더함
	if (PlaybackFrame >= EndFrame)
	{
		PlaybackFrame = static_cast<float>(EndFrame);
		bIsPlaying = false;
	}
}

void FSequencePanel::OnRender()
{
	bool bOpen = IsOpen();
	if (!bOpen)
		return;

	ImGui::SetNextWindowSize(ImVec2(900.0f, 300.0f), ImGuiCond_FirstUseEver);
	if (ImGui::Begin(GetPanelName(), &bOpen))
	{
		if (ImGui::Button(bIsPlaying ? "Pause" : "Play"))	//	Play, Pause를 통해 타임라인 재생
		{
			if (!bIsPlaying && PlaybackFrame >= EndFrame)
				PlaybackFrame = static_cast<float>(StartFrame);
			bIsPlaying = !bIsPlaying;
		}
		ImGui::SameLine();

		static constexpr int FPSValues[] = { 30, 45, 60, 90, 144, 240 };
		static const char* FPSLabels[] = { "30", "45", "60", "90", "144", "240" };
		int FPSIndex = 0;
		for (int Index = 0; Index < IM_ARRAYSIZE(FPSValues); ++Index)	// 현재 적용한 FPS 값으로 FPSIndex 초기화
		{
			if (FPSValues[Index] == PlaybackFPS)
			{
				FPSIndex = Index;
				break;
			}
		}
		ImGui::SetNextItemWidth(100.0f);
		bool bRangeChanged = ImGui::Combo("FPS", &FPSIndex, FPSLabels, IM_ARRAYSIZE(FPSLabels));
		if (bRangeChanged)	// ComboBox에 따른 FPSIndex 세팅
			PlaybackFPS = FPSValues[FPSIndex]; // FPSIndex 기반으로 값 호출

		ImGui::SameLine();
		ImGui::Text("Frame: %.2f", PlaybackFrame);

		static const char* TrackLabels[] = { "Camera", "Fade In", "Fade Out" };
		ImGui::SetNextItemWidth(140.0f);
		ImGui::Combo("Track", &SelectedTrack, TrackLabels, IM_ARRAYSIZE(TrackLabels));
		FTimelineTrack& SelectedRow = Rows[SelectedTrack];
		auto WithSections = [](FTimelineTrack& Row, auto&& Action)
		{
			if (auto* CameraRow = std::get_if<FCameraTimelineTrack>(&Row.Rows))
				Action(CameraRow->CamSections);
			else if (auto* FadeRow = std::get_if<FFadeTimelineTrack>(&Row.Rows))
				Action(FadeRow->FadeSections);
		};
		const int32 KeyFrame = FMath::Clamp(static_cast<int32>(PlaybackFrame), StartFrame, EndFrame);
		bool bCanAddKey = false;
		bool bHasSections = false;
		int TotalKeys = 0;
		WithSections(SelectedRow, [&](auto& Sections)
		{
			bHasSections = !Sections.empty();
			bCanAddKey = Sections.empty() || Sections.back().KeyCount == 2 ||
				Sections.back().KeyFrames[0] != KeyFrame;
			for (const auto& Section : Sections)
				TotalKeys += Section.KeyCount;
		});
		ImGui::SameLine();
		ImGui::BeginDisabled(!bCanAddKey);
		const bool bAddKeyRequested = ImGui::Button("Add Key");
		ImGui::EndDisabled();
		ImGui::SameLine();
		ImGui::BeginDisabled(!bHasSections);
		const bool bClearKeysRequested = ImGui::Button("Clear Keys");
		ImGui::EndDisabled();
		ImGui::SameLine();
		ImGui::Text("Keys: %d", TotalKeys);

		const ImVec2 BodyAvailable = ImGui::GetContentRegionAvail();
		const float FooterY = ImGui::GetCursorPosY() + ImMax(0.0f, BodyAvailable.y - ImGui::GetFrameHeight());
		const float TimelineHeight = BodyAvailable.y - ImGui::GetFrameHeightWithSpacing();
		if (BodyAvailable.x > 240.0f && TimelineHeight > 80.0f)
		{
			if (ImGui::BeginChild("SequenceTimelineArea", ImVec2(0.0f, TimelineHeight)))
			{
				int32 DisplayFrame = static_cast<int32>(PlaybackFrame);
				const int32 PreviousDisplayFrame = DisplayFrame;
				const ImGuiNeoSequencerFlags Flags = ImGuiNeoSequencerFlags_EnableSelection |
					ImGuiNeoSequencerFlags_Selection_EnableDragging;
				if (ImGui::BeginNeoSequencer("SequenceTimeline", &DisplayFrame, &StartFrame, &EndFrame,
					ImGui::GetContentRegionAvail(), Flags))
				{
					if (!ImGui::NeoIsDraggingSelection() && (bAddKeyRequested || bClearKeysRequested))
					{
						ImGui::NeoClearSelection();
						WithSections(SelectedRow, [&](auto& Sections)
						{
							if (bClearKeysRequested)
								Sections.clear();
							else if (bCanAddKey)
							{
								if (Sections.empty() || Sections.back().KeyCount == 2)
									Sections.emplace_back();
								auto& Section = Sections.back();
								Section.KeyFrames[Section.KeyCount++] = KeyFrame;
							}
						});
						bIsPlaying = false;
					}
					for (FTimelineTrack& Row : Rows)
					{
						if (ImGui::BeginNeoTimelineEx(Row.Name))
						{
							WithSections(Row, [&](auto& Sections)
							{
								for (auto& Section : Sections)
								{
									if (Section.KeyCount == 2)
									{
										const int32 From = FMath::Min(Section.KeyFrames[0], Section.KeyFrames[1]);
										const int32 To = FMath::Max(Section.KeyFrames[0], Section.KeyFrames[1]);
										ImGui::NeoDrawTimelineRect(From, To, Row.Color);
									}
									for (int Index = 0; Index < Section.KeyCount; ++Index)
									{
										const int32 PreviousKeyFrame = Section.KeyFrames[Index];
										ImGui::NeoKeyframe(&Section.KeyFrames[Index]);
										Section.KeyFrames[Index] = FMath::Clamp(Section.KeyFrames[Index], StartFrame, EndFrame);
										if (Section.KeyFrames[Index] != PreviousKeyFrame)
											bIsPlaying = false;
									}
								}
							});
							ImGui::EndNeoTimeLine();
						}
					}
					ImGui::EndNeoSequencer();
				}
				if (DisplayFrame != PreviousDisplayFrame)
				{
					PlaybackFrame = static_cast<float>(DisplayFrame);
					bIsPlaying = false;
				}
			}
			ImGui::EndChild();
		}

		ImGui::SetCursorPosY(FooterY);
		const float DurationWidth = 100.0f;
		const float DurationTotalWidth = DurationWidth + ImGui::GetStyle().ItemInnerSpacing.x +
			ImGui::CalcTextSize("Duration (s)").x;
		ImGui::SetCursorPosX(ImGui::GetCursorPosX() +
			ImMax(0.0f, ImGui::GetContentRegionAvail().x - DurationTotalWidth));
		ImGui::SetNextItemWidth(DurationWidth);
		bRangeChanged |= ImGui::InputInt("Duration (s)", &EndFrameSecond, 0, 0);
		if (bRangeChanged)
		{
			const int32 MaxSeconds = (std::numeric_limits<int32>::max() - StartFrame) / PlaybackFPS;
			EndFrameSecond = FMath::Clamp(EndFrameSecond, 1, MaxSeconds);
			EndFrame = StartFrame + EndFrameSecond * PlaybackFPS;
			if (PlaybackFrame >= EndFrame)
			{
				PlaybackFrame = static_cast<float>(EndFrame);
				bIsPlaying = false;
			}
		}
	}
	ImGui::End();

	SetOpen(bOpen);
}
