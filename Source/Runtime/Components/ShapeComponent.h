#pragma once

#include "PrimitiveComponent.h"

struct FCollisionShape;
struct FCollisionContact;
class FLineBatcher;

class UShapeComponent : public UPrimitiveComponent
{
	DECLARE_CLASS(UShapeComponent, UPrimitiveComponent)
	REFLECT_START(UShapeComponent)
		PROPERTY(ShapeColor)
		PROPERTY(bDrawOnlyIfSelected)
	REFLECT_END()

public:
	virtual FCollisionShape GetCollisionShape() const = 0;
	void DrawDebug(FLineBatcher& LineBatcher, bool bHighlight) const;

	bool IsOverlapping(const UShapeComponent& Other) const;
	bool ComputeContact(const UShapeComponent& Other, FCollisionContact& OutContact) const;
	bool ShouldDrawOnlyIfSelected() const;
	float GetShapeScale() const;

protected:
	virtual bool ShouldCreateRenderState() const override;

	FColor ShapeColor{ 223, 149, 157, 255 };
	bool bDrawOnlyIfSelected = false;
};
