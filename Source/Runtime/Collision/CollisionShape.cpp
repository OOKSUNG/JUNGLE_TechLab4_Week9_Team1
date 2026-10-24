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

bool Collision::Overlap(const FCollisionShape& A, const FVector& PosA, const FQuat& RotA,
                        const FCollisionShape& B, const FVector& PosB, const FQuat& RotB,
                        FCollisionContact* OutContact)
{
	if ((A.IsSphere() || A.IsCapsule()) && (B.IsSphere() || B.IsCapsule()))
	{
		FCapsuleSegment CapA = Collision::ToCapsuleSegment(A, PosA, RotA);
		FCapsuleSegment CapB = Collision::ToCapsuleSegment(B, PosB, RotB);
		FCollisionContact C;

		return OverlapCapsuleCapsule(CapA, CapB, &C);
	}
	else if ((A.IsSphere() || A.IsCapsule()) && B.IsBox() ||
	         A.IsBox() && (B.IsSphere() || B.IsCapsule()))
	{
	}
	else if (A.IsBox() && B.IsBox())
	{
	}

	return false;
}

bool Collision::OverlapCapsuleCapsule(const FCapsuleSegment& A, const FCapsuleSegment& B, FCollisionContact* OutContact)
{
	FVector C1, C2;
	float SumR = A.Radius + B.Radius;
	float DistSq = ClosestPointsSegmentSegment(A.A, A.B, B.A, B.B, C1, C2);
	return DistSq <= SumR * SumR;
}

bool Collision::OverlapCapsuleBox(const FCapsuleSegment& Capsule, const FOrientedBox& Box, FCollisionContact* OutContact)
{
	return false;
}

bool Collision::OverlapBoxBox(const FOrientedBox& A, const FOrientedBox& B, FCollisionContact* OutContact)
{
	return false;
}

FVector Collision::ClosestPointOnSegment(const FVector& P, const FVector& A, const FVector& B)
{
	FVector BA = B - A;

	if (BA.Dot(BA) < SMALL_NUMBER)
	{
		return A;
	}

	FVector PA = P - A;

	float T = PA.Dot(BA) / BA.Dot(BA);
	T = std::clamp(T, 0.0f, 1.0f);

	FVector C = A + BA * T;

	return C;
}

float Collision::ClosestPointsSegmentSegment(const FVector& P1, const FVector& Q1, const FVector& P2, const FVector& Q2, FVector& OutC1, FVector& OutC2)
{
	FVector D1 = Q1 - P1;
	FVector D2 = Q2 - P2;
	FVector R = P1 - P2;

	float A = D1.Dot(D1);
	float E = D2.Dot(D2);
	float F = D2.Dot(R);

	if (A < SMALL_NUMBER && E < SMALL_NUMBER)
	{
		OutC1 = P1;
		OutC2 = P2;
		return R.Dot(R);
	}
	else if (A < SMALL_NUMBER)
	{
		OutC1 = P1;
		OutC2 = P2 + D2 * std::clamp(F / E, 0.0f, 1.0f);
		FVector D = OutC2 - OutC1;
		return D.Dot(D);
	}
	else if (E < SMALL_NUMBER)
	{
		float C = D1.Dot(R);
		OutC1 = P1 + D1 * std::clamp(-C / A, 0.0f, 1.0f);
		OutC2 = P2;
		FVector D = OutC2 - OutC1;
		return D.Dot(D);
	}
	else
	{
		float B = D1.Dot(D2);
		float C = D1.Dot(R);
		float Denom = A * E - B * B;

		float S = Denom > SMALL_NUMBER ? std::clamp((B * F - C * E) / Denom, 0.0f, 1.0f) : 0.0f;
		float T = (B * S + F) / E;

		if (T < 0.0f)
		{
			T = 0.0f;
			S = std::clamp(-C / A, 0.0f, 1.0f);
		}
		else if (T > 1.0f)
		{
			T = 1.0f;
			S = std::clamp((B - C) / A, 0.0f, 1.0f);
		}

		OutC1 = P1 + D1 * S;
		OutC2 = P2 + D2 * T;
		FVector D = OutC2 - OutC1;
		return D.Dot(D);
	}
}

FVector Collision::ClosestPointOnBox(const FVector& P, const FOrientedBox& Box)
{
	return FVector();
}
