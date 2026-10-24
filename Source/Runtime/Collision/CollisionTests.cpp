#include "EnginePCH.h"
#include "CollisionTests.h"
#include "CollisionShape.h"

#include "Components/BoxComponent.h"
#include "Components/SphereComponent.h"
#include "Components/CapsuleComponent.h"

namespace
{
	int32 NumChecks = 0;
	int32 NumFailed = 0;

	bool NearlyEqual(float A, float B, float Tolerance = KINDA_SMALL_NUMBER)
	{
		return std::abs(A - B) <= Tolerance;
	}

	bool NearlyEqual(const FVector& A, const FVector& B, float Tolerance = KINDA_SMALL_NUMBER)
	{
		return NearlyEqual(A.X, B.X, Tolerance) && NearlyEqual(A.Y, B.Y, Tolerance) && NearlyEqual(A.Z, B.Z, Tolerance);
	}

	void Check(bool bCondition, const char* Expression, int32 Line)
	{
		++NumChecks;
		if (!bCondition)
		{
			++NumFailed;
			HTR_LOG(Error, "[CollisionTest] FAILED line {}: {}", Line, Expression);
		}
	}

	void CheckFloat(float Actual, float Expected, const char* Expression, int32 Line)
	{
		++NumChecks;
		if (!NearlyEqual(Actual, Expected))
		{
			++NumFailed;
			HTR_LOG(Error, "[CollisionTest] FAILED line {}: {} = {:.4f}, expected {:.4f}", Line, Expression, Actual, Expected);
		}
	}

	void CheckVector(const FVector& Actual, const FVector& Expected, const char* Expression, int32 Line)
	{
		++NumChecks;
		if (!NearlyEqual(Actual, Expected))
		{
			++NumFailed;
			HTR_LOG(Error, "[CollisionTest] FAILED line {}: {} = ({:.4f}, {:.4f}, {:.4f}), expected ({:.4f}, {:.4f}, {:.4f})",
				Line, Expression, Actual.X, Actual.Y, Actual.Z, Expected.X, Expected.Y, Expected.Z);
		}
	}

	// FRotator 인자 순서는 (Pitch, Yaw, Roll)이다. 이 엔진은 +Pitch가 아래를 향한다.
	FQuat MakeRotation(float Pitch, float Yaw, float Roll)
	{
		return FRotator(Pitch, Yaw, Roll).Quaternion();
	}
}

#define CHECK_TRUE(Cond) Check((Cond), #Cond, __LINE__)
#define CHECK_FLOAT(Actual, Expected) CheckFloat((Actual), (Expected), #Actual, __LINE__)
#define CHECK_VECTOR(Actual, Expected) CheckVector((Actual), (Expected), #Actual, __LINE__)

namespace
{
	void TestMakeShapes()
	{
		const FCollisionShape Box = FCollisionShape::MakeBox(FVector(1.0f, 2.0f, 3.0f));
		CHECK_TRUE(Box.IsBox());
		CHECK_VECTOR(Box.BoxHalfExtent, FVector(1.0f, 2.0f, 3.0f));

		const FCollisionShape Sphere = FCollisionShape::MakeSphere(0.5f);
		CHECK_TRUE(Sphere.IsSphere());
		CHECK_FLOAT(Sphere.Radius, 0.5f);
		CHECK_FLOAT(Sphere.GetCapsuleAxisHalfLength(), 0.0f);

		const FCollisionShape Capsule = FCollisionShape::MakeCapsule(0.5f, 1.0f);
		CHECK_TRUE(Capsule.IsCapsule());
		CHECK_FLOAT(Capsule.GetCapsuleAxisHalfLength(), 0.5f);

		// 컴포넌트는 HalfHeight >= Radius를 지키지만, 판정 코드는 들어오는 값을 믿지 않는다.
		const FCollisionShape ShortCapsule = FCollisionShape::MakeCapsule(0.5f, 0.3f);
		CHECK_FLOAT(ShortCapsule.GetCapsuleAxisHalfLength(), 0.0f);
	}

	void TestOrientedBox()
	{
		const FCollisionShape Box = FCollisionShape::MakeBox(FVector(1.0f, 2.0f, 3.0f));

		const Collision::FOrientedBox Identity = Collision::ToOrientedBox(Box, FVector(1.0f, 2.0f, 3.0f), FQuat());
		CHECK_VECTOR(Identity.Center, FVector(1.0f, 2.0f, 3.0f));
		CHECK_VECTOR(Identity.Axis[0], FVector(1.0f, 0.0f, 0.0f));
		CHECK_VECTOR(Identity.Axis[1], FVector(0.0f, 1.0f, 0.0f));
		CHECK_VECTOR(Identity.Axis[2], FVector(0.0f, 0.0f, 1.0f));
		CHECK_VECTOR(Identity.Extent, FVector(1.0f, 2.0f, 3.0f));

		// Yaw 90°: X축이 +Y로, Y축이 -X로 돈다.
		const Collision::FOrientedBox Yaw90 = Collision::ToOrientedBox(Box, FVector::ZeroVector, MakeRotation(0.0f, 90.0f, 0.0f));
		CHECK_VECTOR(Yaw90.Axis[0], FVector(0.0f, 1.0f, 0.0f));
		CHECK_VECTOR(Yaw90.Axis[1], FVector(-1.0f, 0.0f, 0.0f));
		CHECK_VECTOR(Yaw90.Axis[2], FVector(0.0f, 0.0f, 1.0f));

		// 임의 회전에서도 세 축은 서로 수직인 단위 벡터여야 한다.
		const Collision::FOrientedBox Rotated = Collision::ToOrientedBox(Box, FVector::ZeroVector, MakeRotation(30.0f, 45.0f, 60.0f));
		for (int32 i = 0; i < 3; ++i)
		{
			CHECK_FLOAT(Rotated.Axis[i].Size(), 1.0f);
			CHECK_FLOAT(Rotated.Axis[i].Dot(Rotated.Axis[(i + 1) % 3]), 0.0f);
		}
	}

	void TestCapsuleSegment()
	{
		const FCollisionShape Capsule = FCollisionShape::MakeCapsule(0.5f, 1.0f);

		// 회전 없음: 선분은 Z축 방향, A가 아래(−Up) B가 위(+Up)
		const Collision::FCapsuleSegment Upright = Collision::ToCapsuleSegment(Capsule, FVector(1.0f, 2.0f, 3.0f), FQuat());
		CHECK_VECTOR(Upright.A, FVector(1.0f, 2.0f, 2.5f));
		CHECK_VECTOR(Upright.B, FVector(1.0f, 2.0f, 3.5f));
		CHECK_FLOAT(Upright.Radius, 0.5f);

		// Pitch 90°: 이 엔진에서는 Up 축이 +X로 눕는다.
		const Collision::FCapsuleSegment Lying = Collision::ToCapsuleSegment(Capsule, FVector::ZeroVector, MakeRotation(90.0f, 0.0f, 0.0f));
		CHECK_VECTOR(Lying.A, FVector(-0.5f, 0.0f, 0.0f));
		CHECK_VECTOR(Lying.B, FVector(0.5f, 0.0f, 0.0f));

		// Sphere는 길이 0인 선분
		const Collision::FCapsuleSegment Sphere = Collision::ToCapsuleSegment(FCollisionShape::MakeSphere(0.7f), FVector(4.0f, 5.0f, 6.0f), MakeRotation(10.0f, 20.0f, 30.0f));
		CHECK_VECTOR(Sphere.A, FVector(4.0f, 5.0f, 6.0f));
		CHECK_VECTOR(Sphere.B, FVector(4.0f, 5.0f, 6.0f));
		CHECK_FLOAT(Sphere.Radius, 0.7f);

		// HalfHeight < Radius도 길이 0이어야 한다 (A와 B가 뒤집히면 안 된다).
		const Collision::FCapsuleSegment Short = Collision::ToCapsuleSegment(FCollisionShape::MakeCapsule(0.5f, 0.3f), FVector::ZeroVector, FQuat());
		CHECK_VECTOR(Short.A, Short.B);
	}

	void TestComponentShapes()
	{
		// 컴포넌트의 GetCollisionShape()는 스케일 적용된 크기만 담는다.
		UBoxComponent* Box = NewObject<UBoxComponent>();
		Box->SetBoxExtent(FVector(0.5f, 0.5f, 0.5f));
		Box->SetRelativeScale3D(FVector(2.0f, 1.0f, -3.0f));
		const FCollisionShape BoxShape = Box->GetCollisionShape();
		CHECK_TRUE(BoxShape.IsBox());
		CHECK_VECTOR(BoxShape.BoxHalfExtent, FVector(1.0f, 0.5f, 1.5f));
		delete Box;

		// Sphere는 최소 축 스케일을 쓴다.
		USphereComponent* Sphere = NewObject<USphereComponent>();
		Sphere->SetSphereRadius(0.5f);
		Sphere->SetRelativeScale3D(FVector(1.0f, 1.0f, 3.0f));
		const FCollisionShape SphereShape = Sphere->GetCollisionShape();
		CHECK_TRUE(SphereShape.IsSphere());
		CHECK_FLOAT(SphereShape.Radius, 0.5f);
		delete Sphere;

		UCapsuleComponent* Capsule = NewObject<UCapsuleComponent>();
		Capsule->SetCapsuleSize(0.5f, 1.0f);
		Capsule->SetRelativeScale3D(FVector(2.0f, 2.0f, 2.0f));
		const FCollisionShape CapsuleShape = Capsule->GetCollisionShape();
		CHECK_TRUE(CapsuleShape.IsCapsule());
		CHECK_FLOAT(CapsuleShape.Radius, 1.0f);
		CHECK_FLOAT(CapsuleShape.HalfHeight, 2.0f);
		delete Capsule;
	}

	void TestSegmentClosestPoints()
	{
		CHECK_VECTOR(Collision::ClosestPointOnSegment(FVector(0.5f, 1.0f, 0.0f), FVector(0, 0, 0), FVector(1, 0, 0)), FVector(0.5f, 0.0f, 0.0f));
		CHECK_VECTOR(Collision::ClosestPointOnSegment(FVector(3.0f, 1.0f, 0.0f), FVector(0, 0, 0), FVector(1, 0, 0)), FVector(1.0f, 0.0f, 0.0f));

		FVector C1, C2;

		// 십자로 엇갈림
		CHECK_FLOAT(Collision::ClosestPointsSegmentSegment(FVector(-1, 0, 0), FVector(1, 0, 0), FVector(0, -1, 1), FVector(0, 1, 1), C1, C2), 1.0f);
		CHECK_VECTOR(C1, FVector(0, 0, 0));
		CHECK_VECTOR(C2, FVector(0, 0, 1));

		// 평행
		CHECK_FLOAT(Collision::ClosestPointsSegmentSegment(FVector(0, 0, 0), FVector(2, 0, 0), FVector(0, 1, 0), FVector(2, 1, 0), C1, C2), 1.0f);

		// 일직선, 끝점끼리
		CHECK_FLOAT(Collision::ClosestPointsSegmentSegment(FVector(0, 0, 0), FVector(1, 0, 0), FVector(2, 0, 0), FVector(3, 0, 0), C1, C2), 1.0f);
		CHECK_VECTOR(C1, FVector(1, 0, 0));
		CHECK_VECTOR(C2, FVector(2, 0, 0));

		// 한쪽 끝에서 잘림
		CHECK_FLOAT(Collision::ClosestPointsSegmentSegment(FVector(0, 0, 0), FVector(1, 0, 0), FVector(2, -1, 1), FVector(2, 1, 1), C1, C2), 2.0f);
		CHECK_VECTOR(C1, FVector(1, 0, 0));
		CHECK_VECTOR(C2, FVector(2, 0, 1));

		// 점과 선분
		CHECK_FLOAT(Collision::ClosestPointsSegmentSegment(FVector(0, 1, 0), FVector(0, 1, 0), FVector(-1, 0, 0), FVector(1, 0, 0), C1, C2), 1.0f);
		CHECK_VECTOR(C2, FVector(0, 0, 0));
	}

	void TestCapsuleOverlap()
	{
		const FCollisionShape Sphere = FCollisionShape::MakeSphere(0.5f);
		const FCollisionShape Capsule = FCollisionShape::MakeCapsule(0.5f, 1.0f);
		const FQuat Identity;
		const FQuat Lying = MakeRotation(90.0f, 0.0f, 0.0f);

		// 경계(거리 = 반지름 합)는 겹침
		CHECK_TRUE(Collision::Overlap(Sphere, FVector(0, 0, 0), Identity, Sphere, FVector(1.0f, 0, 0), Identity));
		CHECK_TRUE(!Collision::Overlap(Sphere, FVector(0, 0, 0), Identity, Sphere, FVector(1.01f, 0, 0), Identity));

		// 세운 캡슐과 눕힌 캡슐이 십자로
		CHECK_TRUE(Collision::Overlap(Capsule, FVector(0, 0, 0), Identity, Capsule, FVector(0, 0.9f, 0), Lying));
		CHECK_TRUE(!Collision::Overlap(Capsule, FVector(0, 0, 0), Identity, Capsule, FVector(0, 1.1f, 0), Lying));

		// 캡슐 위 반구 끝과 구
		CHECK_TRUE(Collision::Overlap(Capsule, FVector(0, 0, 0), Identity, Sphere, FVector(0, 0, 1.5f), Identity));
		CHECK_TRUE(!Collision::Overlap(Capsule, FVector(0, 0, 0), Identity, Sphere, FVector(0, 0, 1.6f), Identity));

		// 컴포넌트를 거친 IsOverlapping
		USphereComponent* A = NewObject<USphereComponent>();
		USphereComponent* B = NewObject<USphereComponent>();
		A->SetSphereRadius(0.5f);
		B->SetSphereRadius(0.5f);
		B->SetRelativeLocation(FVector(0.9f, 0, 0));
		CHECK_TRUE(A->IsOverlapping(*B));
		CHECK_TRUE(!A->IsOverlapping(*A));
		B->SetRelativeLocation(FVector(1.5f, 0, 0));
		CHECK_TRUE(!A->IsOverlapping(*B));
		delete A;
		delete B;
	}

	void TestBoxOverlap()
	{
		const FCollisionShape Unit = FCollisionShape::MakeBox(FVector(1.0f, 1.0f, 1.0f));
		const FQuat Identity;
		const FQuat Yaw45 = MakeRotation(0.0f, 45.0f, 0.0f);

		// 면끼리
		CHECK_TRUE(Collision::Overlap(Unit, FVector(0, 0, 0), Identity, Unit, FVector(2.0f, 0, 0), Identity));
		CHECK_TRUE(!Collision::Overlap(Unit, FVector(0, 0, 0), Identity, Unit, FVector(2.01f, 0, 0), Identity));

		// AABB는 겹치지만 실제로는 떨어짐
		CHECK_TRUE(!Collision::Overlap(Unit, FVector(0, 0, 0), Identity, Unit, FVector(2.0f, 2.0f, 0), Yaw45));
		CHECK_TRUE(Collision::Overlap(Unit, FVector(0, 0, 0), Identity, Unit, FVector(1.7f, 1.7f, 0), Yaw45));

		// 포함, 같은 박스
		CHECK_TRUE(Collision::Overlap(Unit, FVector(0, 0, 0), Identity, FCollisionShape::MakeBox(FVector(0.2f, 0.2f, 0.2f)), FVector(0.3f, 0.3f, 0.3f), Yaw45));
		CHECK_TRUE(Collision::Overlap(Unit, FVector(0, 0, 0), Identity, Unit, FVector(0, 0, 0), Identity));

		// 면 축 6개로는 못 거르고 모서리 외적 축으로만 분리되는 경우
		const FCollisionShape Stick = FCollisionShape::MakeBox(FVector(0.3f, 2.0f, 0.3f));
		const FQuat Tilted = MakeRotation(45.0f, 30.0f, 0.0f);
		CHECK_TRUE(!Collision::Overlap(Unit, FVector(0, 0, 0), Identity, Stick, FVector(1.7f, 1.7f, 0), Tilted));
		CHECK_TRUE(Collision::Overlap(Unit, FVector(0, 0, 0), Identity, Stick, FVector(1.2f, 1.2f, 0), Tilted));
	}
}

int32 Collision::RunSelfTests()
{
	NumChecks = 0;
	NumFailed = 0;

	TestMakeShapes();
	TestOrientedBox();
	TestCapsuleSegment();
	TestComponentShapes();
	TestSegmentClosestPoints();
	TestCapsuleOverlap();
	TestBoxOverlap();

	if (NumFailed == 0)
	{
		HTR_LOG(Info, "[CollisionTest] All {} checks passed", NumChecks);
	}
	else
	{
		HTR_LOG(Error, "[CollisionTest] {} of {} checks failed", NumFailed, NumChecks);
	}
	return NumFailed;
}
