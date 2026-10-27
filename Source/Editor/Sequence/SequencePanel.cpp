#include "EnginePCH.h"
#include "SequencePanel.h"
#include <type_traits>

bool FSequencePanel::IsFadeLayoutValid(const FFadeTimelineTrack& Track)
{
	const auto& Sections = Track.FadeSections;
	for (size_t Index = 0; Index < Sections.size(); ++Index)
	{
		const auto& Section = Sections[Index];
		if (Section.KeyCount == 0)
			continue;
		const int32 First = Section.KeyFrames[0];
		const int32 Second = Section.KeyCount == 2 ? Section.KeyFrames[1] : First;
		if (Section.KeyCount == 2 && First == Second)
			return false;
		const int32 From = FMath::Min(First, Second);
		const int32 To = FMath::Max(First, Second);
		for (size_t OtherIndex = 0; OtherIndex < Index; ++OtherIndex)
		{
			const auto& Other = Sections[OtherIndex];
			if (Other.KeyCount == 0)
				continue;
			const int32 OtherFirst = Other.KeyFrames[0];
			const int32 OtherSecond = Other.KeyCount == 2 ? Other.KeyFrames[1] : OtherFirst;
			// 경계를 맞대는 것은 허용하고, 구간 내부의 겹침은 금지한다.
			if (From < FMath::Max(OtherFirst, OtherSecond) && FMath::Min(OtherFirst, OtherSecond) < To)
				return false;
		}
	}
	return true;
}

bool FSequencePanel::Init()
{
	return true;
}

void FSequencePanel::Tick(float DeltaTime)
{
	PreviewPlayer.Tick(DeltaTime);
}

void FSequencePanel::OnRender()
{
	auto& Sequence = PreviewPlayer.GetSequenceData();
	auto& Rows = Sequence.Rows;
	int32 StartFrame = Sequence.StartFrame;
	int32 EndFrame = Sequence.GetEndFrame();
	int PlaybackFPS = Sequence.PlaybackFPS;
	int32 EndFrameSecond = Sequence.EndFrameSecond;
	float PlaybackFrame = PreviewPlayer.GetPlaybackFrame();
	bool bOpen = IsOpen();
	if (!bOpen)
		return;

	ImGui::SetNextWindowSize(ImVec2(900.0f, 300.0f), ImGuiCond_FirstUseEver);
	if (ImGui::Begin(GetPanelName(), &bOpen))
	{
		if (ImGui::Button(PreviewPlayer.IsPlaying() ? "Pause" : "Play"))	//	Play, Pause를 통해 타임라인 재생
		{
			if (PreviewPlayer.IsPlaying())
				PreviewPlayer.Pause();
			else
				PreviewPlayer.Play();
			PlaybackFrame = PreviewPlayer.GetPlaybackFrame();
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

		if (Rows.empty())
		{
			ImGui::TextDisabled("No sequence tracks");
			ImGui::End();
			SetOpen(bOpen);
			return;
		}
		SelectedTrack = FMath::Clamp(SelectedTrack, 0, static_cast<int>(Rows.size()) - 1);
		ImGui::SetNextItemWidth(140.0f);
		if (ImGui::BeginCombo("Track", Rows[SelectedTrack].Name.c_str()))
		{
			for (int Index = 0; Index < static_cast<int>(Rows.size()); ++Index)
			{
				if (ImGui::Selectable(Rows[Index].Name.c_str(), SelectedTrack == Index))
					SelectedTrack = Index;
			}
			ImGui::EndCombo();
		}
		FTimelineTrack& SelectedRow = Rows[SelectedTrack];
		auto* SelectedFadeTrack = std::get_if<FFadeTimelineTrack>(&SelectedRow.Rows);
		const auto* SelectedCameraTrack = std::get_if<FCameraTimelineTrack>(&SelectedRow.Rows);
		CameraKey CameraSnapshot{};
		const bool bHasCameraSnapshot = SelectedCameraTrack && ViewportCameraProvider &&
			ViewportCameraProvider(CameraSnapshot);
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
		if (SelectedCameraTrack && !bHasCameraSnapshot)
			bCanAddKey = false;
		bool bFadeOverlap = false;
		if (SelectedFadeTrack && bCanAddKey)
		{
			auto Candidate = *SelectedFadeTrack;
			if (Candidate.FadeSections.empty() || Candidate.FadeSections.back().KeyCount == 2)
				Candidate.FadeSections.emplace_back();
			auto& Section = Candidate.FadeSections.back();
			Section.KeyFrames[Section.KeyCount++] = KeyFrame;
			bFadeOverlap = !IsFadeLayoutValid(Candidate);
			bCanAddKey = !bFadeOverlap;
		}
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
		if (bFadeOverlap)
			ImGui::TextDisabled("Fade sections cannot overlap");
		if (SelectedFadeTrack)
		{
			ImGui::SetNextItemWidth(140.0f);
			ImGui::SliderFloat("New Key Alpha", &NewFadeKeyAlpha, 0.0f, 1.0f, "%.3f", ImGuiSliderFlags_AlwaysClamp);
			if (!SelectedFadeTrack->FadeSections.empty())
			{
				SelectedFadeSection = FMath::Clamp(SelectedFadeSection, 0,
					static_cast<int>(SelectedFadeTrack->FadeSections.size()) - 1);
				const FString Preview = "Section " + std::to_string(SelectedFadeSection + 1);
				ImGui::SameLine();
				ImGui::SetNextItemWidth(120.0f);
				if (ImGui::BeginCombo("Fade Section", Preview.c_str()))
				{
					for (int Index = 0; Index < static_cast<int>(SelectedFadeTrack->FadeSections.size()); ++Index)
					{
						const FString Label = "Section " + std::to_string(Index + 1);
						if (ImGui::Selectable(Label.c_str(), SelectedFadeSection == Index))
							SelectedFadeSection = Index;
					}
					ImGui::EndCombo();
				}
				auto& Section = SelectedFadeTrack->FadeSections[SelectedFadeSection];
				ImGui::SetNextItemWidth(140.0f);
				bool bAlphaChanged = ImGui::SliderFloat("Key 1 Alpha", &Section.KeyFade.StartAlpha, 0.0f, 1.0f, "%.3f", ImGuiSliderFlags_AlwaysClamp);
				if (Section.KeyCount == 2)
				{
					ImGui::SameLine();
					ImGui::SetNextItemWidth(140.0f);
					bAlphaChanged |= ImGui::SliderFloat("Key 2 Alpha", &Section.KeyFade.EndAlpha, 0.0f, 1.0f, "%.3f", ImGuiSliderFlags_AlwaysClamp);
				}
				if (bAlphaChanged)
					PreviewPlayer.Pause();
			}
		}
		if (SelectedCameraTrack && !bHasCameraSnapshot)
			ImGui::TextDisabled("No active viewport camera");

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
								const int KeyIndex = Section.KeyCount;
								Section.KeyFrames[KeyIndex] = KeyFrame;
								if constexpr (std::is_same_v<std::decay_t<decltype(Section)>, FCameraSection>)
								{
									Section.KeyCam[KeyIndex] = CameraSnapshot;
								}
								else
								{
									float& Alpha = KeyIndex == 0 ? Section.KeyFade.StartAlpha : Section.KeyFade.EndAlpha;
									Alpha = NewFadeKeyAlpha;
									SelectedFadeSection = static_cast<int>(Sections.size()) - 1;
								}
								++Section.KeyCount;
							}
						});
						PreviewPlayer.Pause();
					}
					for (FTimelineTrack& Row : Rows)
					{
						auto* FadeTrack = std::get_if<FFadeTimelineTrack>(&Row.Rows);
						// 드래그 중 여러 키가 함께 이동해도 트랙 전체를 검증한 뒤 승인한다.
						const auto PreviousFadeSections = FadeTrack ? FadeTrack->FadeSections : std::vector<FFadeSection>{};
						if (ImGui::BeginNeoTimelineEx(Row.Name.c_str()))
						{
							WithSections(Row, [&](auto& Sections)
							{
								for (auto& Section : Sections)
								{
									if (Section.KeyCount == 2)
									{
										const int32 From = FMath::Min(Section.KeyFrames[0], Section.KeyFrames[1]);
										const int32 To = FMath::Max(Section.KeyFrames[0], Section.KeyFrames[1]);
										ImGui::NeoDrawTimelineRect(From, To, ImVec4(Row.Color.R, Row.Color.G, Row.Color.B, Row.Color.A));
									}
									for (int Index = 0; Index < Section.KeyCount; ++Index)
									{
										const int32 PreviousKeyFrame = Section.KeyFrames[Index];
										ImGui::NeoKeyframe(&Section.KeyFrames[Index]);
										if (ImGui::IsNeoKeyframeHovered())
										{
											ImGui::BeginTooltip();
											ImGui::Text("Frame: %d", Section.KeyFrames[Index]);
											if constexpr (std::is_same_v<std::decay_t<decltype(Section)>, FCameraSection>)
											{
												const CameraKey& Key = Section.KeyCam[Index];
												ImGui::Text("Location: %.2f, %.2f, %.2f", Key.Location.X, Key.Location.Y, Key.Location.Z);
												ImGui::Text("Rotation: %.2f, %.2f, %.2f", Key.Rotation.Pitch, Key.Rotation.Yaw, Key.Rotation.Roll);
												ImGui::Text("FOV: %.2f", Key.FieldOfView);
											}
											else
											{
												ImGui::Text("Alpha: %.2f", Index == 0 ? Section.KeyFade.StartAlpha : Section.KeyFade.EndAlpha);
											}
											ImGui::EndTooltip();
										}
										Section.KeyFrames[Index] = FMath::Clamp(Section.KeyFrames[Index], StartFrame, EndFrame);
										if (Section.KeyFrames[Index] != PreviousKeyFrame)
											PreviewPlayer.Pause();
									}
								}
							});
							ImGui::EndNeoTimeLine();
						}
						if (FadeTrack && !IsFadeLayoutValid(*FadeTrack))
						{
							for (size_t Index = 0; Index < PreviousFadeSections.size(); ++Index)
							{
								FadeTrack->FadeSections[Index].KeyFrames[0] = PreviousFadeSections[Index].KeyFrames[0];
								FadeTrack->FadeSections[Index].KeyFrames[1] = PreviousFadeSections[Index].KeyFrames[1];
							}
							if (ImGui::NeoIsDraggingSelection())
								ImGui::SetTooltip("Fade sections cannot overlap or have zero duration");
						}
					}
					ImGui::EndNeoSequencer();
				}
				if (DisplayFrame != PreviousDisplayFrame)
				{
					PreviewPlayer.SetPlaybackFrame(static_cast<float>(DisplayFrame));
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
			PreviewPlayer.SetPlaybackSettings(PlaybackFPS, EndFrameSecond);
		}
	}
	ImGui::End();

	SetOpen(bOpen);
}
