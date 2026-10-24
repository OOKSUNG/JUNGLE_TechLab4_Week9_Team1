#pragma once

#include "PrimitiveComponent.h"
#include "Core/TDelegate.h"

struct FCollisionShape;
struct FCollisionContact;
class FLineBatcher;
class AActor;

class UShapeComponent : public UPrimitiveComponent
{
	DECLARE_CLASS(UShapeComponent, UPrimitiveComponent)
	REFLECT_START(UShapeComponent)
		PROPERTY(ShapeColor)
		PROPERTY(bDrawOnlyIfSelected)
		PROPERTY(bEnableCollision)
	REFLECT_END()

public:
	UShapeComponent();

	DECLARE_DELEGATE(DelegateWhenBeginOverlap)
	DECLARE_DELEGATE(DelegateWhenEndOverlap)
	DECLARE_DELEGATE(DelegateWhenHit, UPrimitiveComponent*, AActor*, UPrimitiveComponent*, const FHitResult&)

	void OnBeginOverlap();
	void OnEndOverlap();
	void OnHit(AActor* OtherActor, UPrimitiveComponent* OtherComp, const FHitResult& Hit);

	virtual FCollisionShape GetCollisionShape() const = 0;
	void DrawDebug(FLineBatcher& LineBatcher, bool bHighlight) const;

	bool IsOverlapping(const UShapeComponent& Other) const;
	bool ComputeContact(const UShapeComponent& Other, FCollisionContact& OutContact) const;
	bool ShouldDrawOnlyIfSelected() const;
	float GetShapeScale() const;
	bool IsEnableCollision() const { return bEnableCollision; }
	void SetEnableCollision(bool bCollision)
	{
		bEnableCollision = bCollision;
		MarkRenderStateDirty();
	}

protected:
	virtual bool ShouldCreateRenderState() const override;

	FColor ShapeColor{ 223, 149, 157, 255 };
	bool bDrawOnlyIfSelected = false;
	bool bEnableCollision = false; // 충돌 감지 여부
};
