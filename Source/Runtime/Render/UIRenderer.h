#pragma once

#include "EnginePCH.h"
#include "Text/TextRenderer.h"
#include "Text/Font.h"

struct UITextInfo
{
	float TextSize;
	FString Text;
	UFont* Atlas = nullptr;
	// 화면의 비율 좌표(0~1), UI 자체의 정렬 기준점(0~1).
	FVector2 Anchor = FVector2();
	FVector2 Alignment = FVector2();
	FVector2 Offset = FVector2(); // 앵커에서의 픽셀 여백
};

struct UIImageInfo
{
	FVector2 Size;
	UTexture2D* Texture = nullptr;
	FVector2 Anchor = FVector2();
	FVector2 Alignment = FVector2();
	FVector2 Offset = FVector2();
	float Ratio = 1.0f; // 0~1, 왼쪽부터 표시할 비율
};

class FUIRenderer
{
public:
	void Init(FTextRenderer& TextRenderer);

	void DrawUIText(const UITextInfo& TextInfo, float Width, float Height);
	// 그리기 패스 안에서 호출한다. 좌표 원점은 화면 왼쪽 위다.
	void RenderUIText(float Width, float Height);
	void DrawUIImage(const UIImageInfo& ImageInfo, float Width, float Height);
	void RenderUIImage(float Width, float Height);

	void AddUIText(UITextInfo TextInfo) { UITextArray.Add(TextInfo); }
	void AddUIImage(UIImageInfo ImageInfo) { UIImageArray.Add(ImageInfo);  }
	
	void ResetUIText() { UITextArray.Reset(); }
	void ResetUIImage() { UIImageArray.Reset(); }

private:
	FTextRenderer* TextRenderer = nullptr;
	FPipelineState UIPipeline;
	FPipelineState UIImagePipeline;
	TUniquePtr<FConstantBuffer> UIImageConstants;
	TArray<UITextInfo> UITextArray;
	TArray<UIImageInfo> UIImageArray;
};
