#include "EnginePCH.h"
#include "CollisionShape.h"

FCollisionShape FCollisionShape::MakeBox(const FVector& HalfExtent)
{
	FCollisionShape Box{};
	Box.ShapeType = ECollisionShape::Box;
	Box.BoxHalfExtent = HalfExtent;
	return Box;
}

FCollisionShape FCollisionShape::MakeSphere(float Radius)
{
	FCollisionShape Sphere{};
	Sphere.ShapeType = ECollisionShape::Sphere;
	Sphere.Radius = Radius;
	return Sphere;
}

FCollisionShape FCollisionShape::MakeCapsule(float Radius, float HalfHeight)
{
	FCollisionShape Capsule{};
	Capsule.ShapeType = ECollisionShape::Capsule;
	Capsule.Radius = Radius;
	Capsule.HalfHeight = HalfHeight;
	return Capsule;
}

bool FCollisionShape::IsBox() const
{
	return ShapeType == ECollisionShape::Box;
}

bool FCollisionShape::IsSphere() const
{
	return ShapeType == ECollisionShape::Sphere;
}

bool FCollisionShape::IsCapsule() const
{
	return ShapeType == ECollisionShape::Capsule;
}

float FCollisionShape::GetCapsuleAxisHalfLength() const
{
	return std::max(0.0f, HalfHeight - Radius);
}

Collision::FCapsuleSegment Collision::ToCapsuleSegment(const FCollisionShape& Shape, const FVector& Pos, const FQuat& Rot)
{
	FVector Temp = Rot.GetUpVector() * Shape.GetCapsuleAxisHalfLength();
	return FCapsuleSegment{
		Pos - Temp,
		Pos + Temp,
		Shape.Radius
	};
}

Collision::FOrientedBox Collision::ToOrientedBox(const FCollisionShape& Shape, const FVector& Pos, const FQuat& Rot)
{
	return FOrientedBox{
		Pos,
		{ Rot.GetForwardVector(), Rot.GetRightVector(), Rot.GetUpVector() },
		Shape.BoxHalfExtent
	};
}
