#pragma once

#include "Core/Types.h"
#include "Math/Vector.h"
#include "Math/Quat.h"

enum class ECollisionShape : uint8
{
	None,
	Box,
	Sphere,
	Capsule
};

struct FCollisionShape
{
	ECollisionShape ShapeType = ECollisionShape::None;
	FVector BoxHalfExtent;
	float Radius = 0.0f;
	float HalfHeight = 0.0f;

	static FCollisionShape MakeBox(const FVector& HalfExtent);
	static FCollisionShape MakeSphere(float Radius);
	static FCollisionShape MakeCapsule(float Radius, float HalfHeight);

	bool IsBox() const;
	bool IsSphere() const;
	bool IsCapsule() const;
	float GetCapsuleAxisHalfLength() const;
};

struct FCollisionContact
{
	FVector Normal;
	float PenetrationDepth = 0.0f;
	FVector Point;
};

namespace Collision
{
	struct FCapsuleSegment
	{
		FVector A, B;
		float Radius = 0.0f;
	};

	struct FOrientedBox
	{
		FVector Center;
		FVector Axis[3];
		FVector Extent;
	};

	FCapsuleSegment ToCapsuleSegment(const FCollisionShape& Shape, const FVector& Pos, const FQuat& Rot);
	FOrientedBox ToOrientedBox(const FCollisionShape& Shape, const FVector& Pos, const FQuat& Rot);
}
