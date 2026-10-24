#include "EnginePCH.h"
#include "Scripting/LuaVM.h"

#include "GameFramework/Actor.h"
#include "Components/SceneComponent.h"
#include "Math/Vector.h"
#include "Math/Rotator.h"

#include <sol/sol.hpp>
#include <luajit.h>

namespace
{
	bool CheckLuaResult(
		sol::protected_function_result& Result,
		const FString& Context
	)
	{
		if (Result.valid())
		{
			return true;
		}

		sol::error Error = Result;
		HTR_LOG(
			Error,
			"[Lua] {} failed: {}",
			Context,
			Error.what()
		);

		return false;
	}

	FString LuaValueToString(const sol::object& Value)
	{
		switch (Value.get_type())
		{
		case sol::type::nil:
			return "nil";

		case sol::type::string:
			return Value.as<FString>();

		case sol::type::number:
			return std::format("{}", Value.as<double>());

		case sol::type::boolean:
			return Value.as<bool>() ? "true" : "false";

		default:
			return "<value>";
		}
	}

	void BindLoggingAPI(sol::state& LuaState)
	{
		auto LogFunction = [](sol::variadic_args Args)
			{
				FString Message;

				for (const auto& Argument : Args)
				{
					if (!Message.empty())
					{
						Message += " ";
					}

					const sol::object Value = Argument;
					Message += LuaValueToString(Value);
				}

				HTR_LOG(Info, "[Lua] {}", Message);

				Message += "\n";
				OutputDebugStringA(Message.c_str());
			};

		// Lua에서 Log("Score:", 100, true)처럼 호출할 수 있습니다.
		LuaState.set_function("Log", LogFunction);

		// 기본 Lua print도 에디터 Output Log 쪽으로 연결합니다.
		LuaState.set_function("print", LogFunction);
	}

	void BindVectorAPI(sol::state& LuaState)
	{
		LuaState.new_usertype<FVector>(
			"FVector",
			sol::constructors<
				FVector(),
				FVector(float, float, float)
			>(),
			"X", &FVector::X,
			"Y", &FVector::Y,
			"Z", &FVector::Z,
			"Set", &FVector::Set,
			"Size", &FVector::Size,
			"SizeSquared", &FVector::SizeSquared,
			"Length", &FVector::Length,
			"Normalized", &FVector::Normalized,
			"Add", &FVector::Add,
			"Subtract", &FVector::Subtract,
			"Dot", [](const FVector& A, const FVector& B)
			{
				return FVector::Dot(A, B);
			},
			"Cross", [](const FVector& A, const FVector& B)
			{
				return FVector::Cross(A, B);
			},
			"Distance", [](const FVector& A, const FVector& B)
			{
				return FVector::Distance(A, B);
			},
			sol::meta_function::addition,
			[](const FVector& A, const FVector& B)
			{
				return A + B;
			},
			sol::meta_function::subtraction,
			[](const FVector& A, const FVector& B)
			{
				return A - B;
			},
			sol::meta_function::multiplication,
			[](const FVector& Vector, float Scalar)
			{
				return Vector * Scalar;
			},
			sol::meta_function::equal_to,
			[](const FVector& A, const FVector& B)
			{
				return A == B;
			}
		);
	}

	void BindRotatorAPI(sol::state& LuaState)
	{
		LuaState.new_usertype<FRotator>(
			"FRotator",
			sol::constructors<
				FRotator(),
				FRotator(float, float, float)
			>(),
			"Pitch", &FRotator::Pitch,
			"Yaw", &FRotator::Yaw,
			"Roll", &FRotator::Roll
		);
	}

	void BindActorAPI(sol::state& LuaState)
	{
		LuaState.new_usertype<AActor>(
			"AActor",
			sol::no_constructor,
			"GetName", [](const AActor& Actor)
			{
				return Actor.GetName();
			},
			"GetActorLocation", [](const AActor& Actor)
			{
				return Actor.GetActorLocation();
			},
			"SetActorLocation", [](AActor& Actor, const FVector& NewLocation)
			{
				USceneComponent* RootComponent = Actor.GetRootComponent();
				if (!RootComponent)
				{
					return false;
				}

				RootComponent->SetWorldLocation(NewLocation, false);
				return true;
			},
			"GetActorRotation", [](const AActor& Actor)
			{
				return Actor.GetActorRotation();
			},
			"SetActorRotation", [](AActor& Actor, const FRotator& NewRotation)
			{
				USceneComponent* RootComponent = Actor.GetRootComponent();
				if (!RootComponent)
				{
					return false;
				}

				RootComponent->SetWorldRotation(NewRotation, false);
				return true;
			},
			"GetActorScale3D", [](const AActor& Actor)
			{
				return Actor.GetActorScale3D();
			},
			"SetActorScale3D", [](AActor& Actor, const FVector& NewScale)
			{
				USceneComponent* RootComponent = Actor.GetRootComponent();
				if (!RootComponent)
				{
					return false;
				}

				RootComponent->SetWorldScale3D(NewScale);
				return true;
			},
			"Destroy", [](AActor& Actor)
			{
				return Actor.Destroy();
			}
		);
	}
}

FLuaVM::~FLuaVM()
{
	Shutdown();
}

bool FLuaVM::Initialize()
{
	if (State)
	{
		return true;
	}

	try
	{
		State = MakeUnique<sol::state>();

		// 게임 스크립트에 필요한 표준 라이브러리만 엽니다.
		// os, io, debug는 파일 및 시스템 접근이 가능하므로 우선 제외합니다.
		State->open_libraries(
			sol::lib::base,
			sol::lib::package,
			sol::lib::coroutine,
			sol::lib::string,
			sol::lib::table,
			sol::lib::math
		);

		BindEngineAPI();

		HTR_LOG(
			Info,
			"[Lua] VM initialized with {}",
			LUAJIT_VERSION
		);

		return true;
	}
	catch (const std::exception& Exception)
	{
		HTR_LOG(
			Error,
			"[Lua] VM initialization failed: {}",
			Exception.what()
		);

		State.reset();
		return false;
	}
}

void FLuaVM::Shutdown()
{
	if (!State)
	{
		return;
	}

	// sol::state의 소멸자가 내부 lua_State에 lua_close를 호출합니다.
	State.reset();
}

void FLuaVM::BindEngineAPI()
{
	if (!State)
	{
		return;
	}

	BindLoggingAPI(*State);
	BindVectorAPI(*State);
	BindRotatorAPI(*State);
	BindActorAPI(*State);
}

bool FLuaVM::ExecuteString(
	const FString& Source,
	const FString& ChunkName
)
{
	if (!State)
	{
		HTR_LOG(
			Error,
			"[Lua] Cannot execute '{}': VM is not initialized",
			ChunkName
		);
		return false;
	}

	sol::protected_function_result Result =
		State->safe_script(
			Source,
			sol::script_pass_on_error,
			ChunkName
		);

	return CheckLuaResult(Result, ChunkName);
}

bool FLuaVM::ExecuteFile(const FString& ScriptPath)
{
	if (!State)
	{
		HTR_LOG(
			Error,
			"[Lua] Cannot execute '{}': VM is not initialized",
			ScriptPath
		);
		return false;
	}

	if (!std::filesystem::exists(ScriptPath))
	{
		HTR_LOG(
			Error,
			"[Lua] Script file not found: {}",
			ScriptPath
		);
		return false;
	}

	sol::protected_function_result Result =
		State->safe_script_file(
			ScriptPath,
			sol::script_pass_on_error
		);

	return CheckLuaResult(Result, ScriptPath);
}
