#include "EnginePCH.h"
#include "ShapeComponent.h"

bool UShapeComponent::ShouldCreateRenderState() const
{
	return false;
}

void UShapeComponent::DrawDebug(FLineBatcher& LineBatcher, bool bHighlight) const
{
}

bool UShapeComponent::IsOverlapping(const UShapeComponent& Other) const
{
	return false;
}

bool UShapeComponent::ComputeContact(const UShapeComponent& Other, FCollisionContact& OutContact) const
{
	return false;
}

bool UShapeComponent::ShouldDrawOnlyIfSelected() const
{
	return bDrawOnlyIfSelected;
}

float UShapeComponent::GetShapeScale() const
{
	FVector Scale = GetWorldScale3D();
	return std::min({ std::abs(Scale.X), std::abs(Scale.Y), std::abs(Scale.Z) });
}
