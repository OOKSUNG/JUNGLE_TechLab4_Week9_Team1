#pragma once

#ifdef EXECUTABLE

#include "Engine/GameEngine.h"
#include "Render/FogRenderer.h"
#include "Render/FShadowViewRenderer.h"
#include "Render/FXAARenderer.h"
#include "Render/SkyboxRenderer.h"
#include "Render/ToneMapRenderer.h"
#include "Text/TextRenderer.h"

struct FLODViewContext;

class UExecutableEngine : public UGameEngine {
	DECLARE_CLASS(UExecutableEngine, UGameEngine)

public:
	FEngineConfig GetConfig() const override;
	bool Init() override;
	void Tick(float DeltaTime) override;
	void OnResize(uint32 Width, uint32 Height) override;
	void PreExit() override;

private:
	void RenderFrame(UCameraComponent& Camera);
	void RenderShadows(const UCameraComponent& Camera, const FLODViewContext& View, FViewConstants& ViewConstants);
	void RenderScene(const UCameraComponent& Camera, const FViewConstants& ViewConstants);
	void RenderPostProcess(const UCameraComponent& Camera);
	void RenderText(const FMatrix& ViewProjection);
	static FMatrix BuildBillboardMatrix(const FVector& Position, float Width, float Height, const void* ViewContext);
	static void AppendShadowFrustumCorners(const UCameraComponent& Camera, float NearDistance, float FarDistance, TArray<FVector>& OutCorners);

private:
	UWorld* mWorld{};
	FSkyboxRenderer mSkyboxRenderer{};
	FFogRenderer mFogRenderer{};
	FShadowViewRenderer mShadowViewRenderer{};
	FToneMapRenderer mToneMapRenderer{};
	FFXAARenderer mFXAARenderer{};
	FTextRenderer mTextRenderer{};
	TUniquePtr<FTexture2D> mColorTarget{};
	TUniquePtr<FTexture2D> mDepthTarget{};
	TUniquePtr<FTexture2D> mHDRTarget{};
	FRenderingInfo mRenderingInfo{};
	FRenderQueue mRenderQueue{};
	FRenderQueue mIconQueue{};
	FRenderQueue mArrowQueue{};
};

#endif
