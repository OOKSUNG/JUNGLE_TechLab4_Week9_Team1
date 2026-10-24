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
	else if ((A.IsSphere() || A.IsCapsule()) && B.IsBox())
	{
		FCapsuleSegment CapA = Collision::ToCapsuleSegment(A, PosA, RotA);
		FOrientedBox BoxB = Collision::ToOrientedBox(B, PosB, RotB);
		FCollisionContact C;

		return OverlapCapsuleBox(CapA, BoxB, &C);
	}
	else if (A.IsBox() && (B.IsSphere() || B.IsCapsule()))
	{
		FOrientedBox BoxA = Collision::ToOrientedBox(A, PosA, RotA);
		FCapsuleSegment CapB = Collision::ToCapsuleSegment(B, PosB, RotB);
		FCollisionContact C;

		return OverlapCapsuleBox(CapB, BoxA, &C);
	}
	else if (A.IsBox() && B.IsBox())
	{
		FOrientedBox BoxA = Collision::ToOrientedBox(A, PosA, RotA);
		FOrientedBox BoxB = Collision::ToOrientedBox(B, PosB, RotB);
		FCollisionContact C;

		return OverlapBoxBox(BoxA, BoxB, &C);
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
	const FVector Dir = Capsule.B - Capsule.A;
	auto DistSqAt = [&](float T)
	{
		const FVector P = Capsule.A + Dir * T;
		const FVector D = P - ClosestPointOnBox(P, Box);
		return D.Dot(D);
	};

	// 선분 위치 t에 대한 박스까지 거리는 볼록 함수라 삼분 탐색으로 최솟값을 찾는다.
	float Lo = 0.0f;
	float Hi = 1.0f;
	for (int32 Iter = 0; Iter < 30; ++Iter)
	{
		const float M1 = Lo + (Hi - Lo) / 3.0f;
		const float M2 = Hi - (Hi - Lo) / 3.0f;
		if (DistSqAt(M1) <= DistSqAt(M2))
			Hi = M2;
		else
			Lo = M1;
	}

	return DistSqAt((Lo + Hi) * 0.5f) <= Capsule.Radius * Capsule.Radius;
}

bool Collision::OverlapBoxBox(const FOrientedBox& A, const FOrientedBox& B, FCollisionContact* OutContact)
{
	constexpr float Epsilon = 1e-6f;

	float R[3][3];
	float AbsR[3][3];
	for (int32 i = 0; i < 3; ++i)
	{
		for (int32 j = 0; j < 3; ++j)
		{
			R[i][j] = A.Axis[i].Dot(B.Axis[j]);
			AbsR[i][j] = std::abs(R[i][j]) + Epsilon;
		}
	}

	const FVector Offset = B.Center - A.Center;
	const float T[3] = { Offset.Dot(A.Axis[0]), Offset.Dot(A.Axis[1]), Offset.Dot(A.Axis[2]) };

	const FVector& EA = A.Extent;
	const FVector& EB = B.Extent;

	// A의 축
	for (int32 i = 0; i < 3; ++i)
	{
		const float RA = EA[i];
		const float RB = EB[0] * AbsR[i][0] + EB[1] * AbsR[i][1] + EB[2] * AbsR[i][2];
		if (std::abs(T[i]) > RA + RB)
			return false;
	}

	// B의 축
	for (int32 j = 0; j < 3; ++j)
	{
		const float RA = EA[0] * AbsR[0][j] + EA[1] * AbsR[1][j] + EA[2] * AbsR[2][j];
		const float RB = EB[j];
		const float Dist = T[0] * R[0][j] + T[1] * R[1][j] + T[2] * R[2][j];
		if (std::abs(Dist) > RA + RB)
			return false;
	}

	// A[i] x B[j]
	for (int32 i = 0; i < 3; ++i)
	{
		const int32 I1 = (i + 1) % 3;
		const int32 I2 = (i + 2) % 3;
		for (int32 j = 0; j < 3; ++j)
		{
			const int32 J1 = (j + 1) % 3;
			const int32 J2 = (j + 2) % 3;

			const float RA = EA[I1] * AbsR[I2][j] + EA[I2] * AbsR[I1][j];
			const float RB = EB[J1] * AbsR[i][J2] + EB[J2] * AbsR[i][J1];
			const float Dist = T[I2] * R[I1][j] - T[I1] * R[I2][j];
			if (std::abs(Dist) > RA + RB)
				return false;
		}
	}

	return true;
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
	const FVector D = P - Box.Center;

	FVector Result = Box.Center;
	for (int32 i = 0; i < 3; ++i)
	{
		const float S = std::clamp(D.Dot(Box.Axis[i]), -Box.Extent[i], Box.Extent[i]);
		Result += Box.Axis[i] * S;
	}
	return Result;
}
