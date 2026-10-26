#include "EnginePCH.h"
#include "UIRenderer.h"

#include "Render/RenderCommand.h"
#include "Render/RenderResourceManager.h"
#include "Render/Texture2D.h"

#include <algorithm>

namespace
{
	struct FUIImageConstants
	{
		FVector2 ClipOrigin;
		FVector2 ClipSize;
		float Ratio;
		float Padding[3] = {};
	};
	static_assert(sizeof(FUIImageConstants) == 32);

	FVector2 ResolveUIPosition(const FVector2& Size,
		const FVector2& Anchor, const FVector2& Alignment, const FVector2& Offset,
		float Width, float Height)
	{
		return FVector2(Width * Anchor.X + Offset.X - Size.X * Alignment.X,
			Height * Anchor.Y + Offset.Y - Size.Y * Alignment.Y);
	}
}

void FUIRenderer::Init(FTextRenderer& TextRender)
{
	TextRenderer = &TextRender;
	UIPipeline = TextRender.GetPipelineState();
	UIPipeline.RasterizerState = ERasterizerState::SolidNone;
	UIPipeline.BlendState = EBlendState::AlphaBlend;
	UIPipeline.DepthStencilState = EDepthStencilState::Disabled;

	UIImagePipeline = UIPipeline;
	UIImagePipeline.Shader = FRenderResourceManager::GetShaderProgram("Resources/Shader/UIImageShader.hlsl");
	UIImageConstants = RenderCommand::CreateConstantBuffer(sizeof(FUIImageConstants));
}

void FUIRenderer::DrawUIText(const UITextInfo& TextInfo, float Width, float Height)
{
	if (!TextRenderer || !TextInfo.Atlas || !TextInfo.Atlas->AtlasTexture ||
		TextInfo.Atlas->Width <= 0.0f || TextInfo.Atlas->Height <= 0.0f ||
		TextInfo.TextSize <= 0.0f || Width <= 0.0f || Height <= 0.0f)
	{
		return;
	}

	float MinY, MaxY, MinZ, MaxZ;
	if (!FTextRenderer::ComputeTextBounds(TextInfo.Text, TextInfo.TextSize, *TextInfo.Atlas,
		MinY, MaxY, MinZ, MaxZ))
	{
		return;
	}

	const FVector2 TextSize(MaxY - MinY, MaxZ - MinZ);
	const FVector2 Position = ResolveUIPosition(TextSize,
		TextInfo.Anchor, TextInfo.Alignment, TextInfo.Offset, Width, Height);

	// 기존 글자 메시의 로컬 Y/Z를 화면의 X/Y 픽셀 좌표로 바꾼다.
	FMatrix UIWorld;
	UIWorld.SetIdentity();
	for (int Row = 0; Row < 3; ++Row)
		for (int Col = 0; Col < 3; ++Col)
			UIWorld.M[Row][Col] = 0.0f;
	UIWorld.M[1][0] = 1.0f;
	UIWorld.M[2][1] = -1.0f;
	UIWorld.M[0][2] = 1.0f;
	UIWorld.M[3][0] = Position.X - MinY;
	UIWorld.M[3][1] = Position.Y + MaxZ;
	FMatrix UIProjection;
	UIProjection.SetIdentity();
	UIProjection.M[0][0] = 2.0f / Width;
	UIProjection.M[1][1] = -2.0f / Height;
	UIProjection.M[3][0] = -1.0f;
	UIProjection.M[3][1] = 1.0f;
	TextRenderer->OnRender(TextInfo.Text, UIWorld, TextInfo.TextSize, *TextInfo.Atlas, UIProjection, UIPipeline);
}

void FUIRenderer::RenderUIText(float Width, float Height)
{
	if (TextRenderer && Width > 0.0f && Height > 0.0f)
	{
		for (const UITextInfo& TextInfo : UITextArray)
		{
			DrawUIText(TextInfo, Width, Height);
		}
	}
	UITextArray.Reset();
}

void FUIRenderer::DrawUIImage(const UIImageInfo& ImageInfo, float Width, float Height)
{
	if (!UIImagePipeline.Shader || !UIImageConstants || !ImageInfo.Texture ||
		!ImageInfo.Texture->GetResource() || ImageInfo.Size.X <= 0.0f || ImageInfo.Size.Y <= 0.0f ||
		Width <= 0.0f || Height <= 0.0f || ImageInfo.Ratio <= 0.0f)
	{
		return;
	}

	const FVector2 Position = ResolveUIPosition(ImageInfo.Size,
		ImageInfo.Anchor, ImageInfo.Alignment, ImageInfo.Offset, Width, Height);
	FUIImageConstants Constants{};
	Constants.ClipOrigin = FVector2(2.0f * Position.X / Width - 1.0f,
		1.0f - 2.0f * Position.Y / Height);
	Constants.ClipSize = FVector2(2.0f * ImageInfo.Size.X / Width, -2.0f * ImageInfo.Size.Y / Height);
	Constants.Ratio = std::clamp(ImageInfo.Ratio, 0.0f, 1.0f);

	RenderCommand::BindPipelineState(UIImagePipeline);
	RenderCommand::UpdateBufferData(UIImageConstants.get(), &Constants);
	RenderCommand::BindConstantBuffer(0, UIImageConstants.get(), EShaderBindFlagBits::Vertex | EShaderBindFlagBits::Pixel);
	RenderCommand::BindShaderResource(0, ImageInfo.Texture, EShaderBindFlagBits::Pixel);
	RenderCommand::BindSamplerState(0, ESamplerState::LinearClamp, EShaderBindFlagBits::Pixel);
	// 정점은 셰이더의 SV_VertexID로 만든다.
	RenderCommand::BindVertexBuffer(nullptr);
	RenderCommand::BindIndexBuffer(nullptr);
	RenderCommand::Draw(6);
	RenderCommand::UnbindShaderResource(0, EShaderBindFlagBits::Pixel);
}

void FUIRenderer::RenderUIImage(float Width, float Height)
{
	for (const UIImageInfo& ImageInfo : UIImageArray)
	{
		DrawUIImage(ImageInfo, Width, Height);
	}
	UIImageArray.Reset();
}
