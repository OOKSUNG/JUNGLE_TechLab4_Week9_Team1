#include "EnemyPatrolEngineTests.h"
#include "EnginePCH.h"
#include "Asset/ObjImporter/ObjImporter.h"
#include "Camera/CameraActor.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/World.h"
#include "Render/Mesh.h"
#include "Scripting/LuaVM.h"
#include "UObject/UObjectGlobals.h"

void FPatrolLogSink::OnLog(ELogVerbosity Verbosity, const FString& Message) {
	if (Verbosity == ELogVerbosity::Error || Message.find("[EnemyPatrolEngineTests]") != FString::npos) {
		std::cout << Message << '\n';
	}
}

bool ValidateMeshRotation(AActor& Actor, USceneComponent& Component) {
	float MaximumError{};
	for (int32 Step{}; Step <= 1440; ++Step) {
		Actor.GetRootComponent()->SetRelativeRotation(FRotator{ 0.0f, static_cast<float>(Step) * 0.25f, 0.0f });
		const FQuat ExpectedRotation{ Actor.GetActorRotation().Quaternion() * Component.GetRelativeRotationQuat() };
		const FMatrix ActualMatrix{ Component.GetWorldMatrix() };
		const FVector Scale{ Component.GetWorldScale3D() };
		const FVector Axes[]{ FVector{ 1.0f, 0.0f, 0.0f }, FVector{ 0.0f, 1.0f, 0.0f }, FVector{ 0.0f, 0.0f, 1.0f } };
		for (const FVector& Axis : Axes) {
			const FVector Expected{ ExpectedRotation.RotateVector(Axis * Scale) };
			const FVector Actual{ ActualMatrix.TransformVector(Axis) };
			MaximumError = std::max(MaximumError, (Expected - Actual).Length());
		}
	}
	Actor.GetRootComponent()->SetRelativeRotation(FRotator{ 0.0f, 0.0f, 0.0f });
	std::cout << "Mesh rotation maximum basis error: " << MaximumError << '\n';
	return MaximumError < 0.00001f;
}

int main() {
	FPatrolLogSink Sink{};
	FLog::AddSink(&Sink);
	FLuaVM Lua{};
	TUniquePtr<FStaticMeshData> Data{ FObjImporter::LoadStaticMeshData("Assets/Models/Monster/Monster.obj") };
	if (!Data || !Lua.Initialize()) {
		FLog::RemoveSink(&Sink);
		return 1;
	}

	UStaticMesh* Mesh{ NewObject<UStaticMesh>() };
	Mesh->MeshData = std::move(*Data);
	UWorld* World{ UWorld::CreateWorld(EWorldType::PIE, false) };
	AActor* Actor{ World->SpawnActor(AActor::StaticClass()) };
	Actor->GetRootComponent()->SetRelativeLocation(FVector{ -22.5f, 4.5f, 0.0f });
	UStaticMeshComponent* Component{ Cast<UStaticMeshComponent>(Actor->AddComponent(UStaticMeshComponent::StaticClass(), FName{ "EnemyMesh" })) };
	Component->SetupAttachment(Actor->GetRootComponent());
	Component->SetRelativeLocation(FVector{ 0.7152f, -0.0672f, 0.2432f });
	Component->SetRelativeRotation(FRotator{ -90.0f, 0.0f, 0.0f });
	Component->SetRelativeScale3D(FVector{ 0.016f, 0.016f, 0.016f });
	Component->SetStaticMesh(Mesh);
	if (!ValidateMeshRotation(*Actor, *Component)) {
		std::cout << "NATIVE MESH ROTATION VALIDATION FAILED\n";
		FLog::RemoveSink(&Sink);
		return 1;
	}
	Actor->GetRootComponent()->SetRelativeRotation(FRotator{ 0.0f, 123.0f, 0.0f });
	Actor->GetRootComponent()->SetRelativeScale3D(FVector{ 1.25f, 0.75f, 1.0f });
	const FQuat WorldToActor{ Actor->GetActorRotation().Quaternion().Inverse() };
	const FMatrix MeshToWorld{ Component->GetWorldMatrix() };
	FVector ExpectedScaledExtent{};
	for (const FVertex& Vertex : Mesh->MeshData.Vertices) {
		const FVector Position{ WorldToActor.RotateVector(MeshToWorld.TransformPosition(Vertex.Position) - Actor->GetActorLocation()) };
		ExpectedScaledExtent.X = std::max(ExpectedScaledExtent.X, std::abs(Position.X));
		ExpectedScaledExtent.Y = std::max(ExpectedScaledExtent.Y, std::abs(Position.Y));
	}
	Actor->GetRootComponent()->SetRelativeRotation(FRotator{ 0.0f, 0.0f, 0.0f });
	Actor->GetRootComponent()->SetRelativeScale3D(FVector{ 1.0f, 1.0f, 1.0f });
	(*Lua.GetState())["PatrolExpectedScaledExtent"] = ExpectedScaledExtent;
	(*Lua.GetState())["PatrolTestOwner"] = Actor;
	const bool Passed{ Lua.ExecuteFile("Tests/Scripting/EnemyPatrolEngineTests.lua") };
	if (Passed) {
		const double Distance{ (*Lua.GetState())["PatrolTestDistance"].get<double>() };
		const int32 Rooms{ (*Lua.GetState())["PatrolTestRoomCount"].get<int32>() };
		std::cout << "Native distance: " << Distance << ", rooms: " << Rooms << '\n';
	}
	(*Lua.GetState())["PatrolTestOwner"] = sol::nil;
	World->ClearWorld();
	ACameraActor* Camera{ World->GetMainCamera() };
	Camera->RegisterAllActorTickFunctions(false);
	delete Camera;
	delete World;
	delete Mesh;
	FLog::RemoveSink(&Sink);
	std::cout << (Passed ? "NATIVE ENEMY PATROL VALIDATION PASSED\n" : "NATIVE ENEMY PATROL VALIDATION FAILED\n");
	return Passed ? 0 : 1;
}
