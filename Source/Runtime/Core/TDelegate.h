#pragma once

#include "EnginePCH.h"

#include <functional>
#include "Containers/Array.h"

#define DECLARE_DELEGATE(Name, ...) TDelegate<__VA_ARGS__> Name	// Delegate 객체 이름, 전체 Parameter를 매크로에 넘기면 해당 TDelegate 객체 생성

template<typename... Args>

class TDelegate
{
public:
	using HandlerType = std::function<void(Args...)>;

	// 일반 함수나 람다 등록
	void Add(const HandlerType& handler)
	{
		Handlers.Add(handler);

	}

	// 클래스 멤버 함수 등록, 람다로 handler 생성후 목록에 저장
	template<typename T>
	void AddDynamic(T* Instance, void (T::* Func)(Args...))
	{
		HandlerType handler = [Instance, Func](Args... args) -> void {(Instance->*Func)(args);};
		Handlers.Add(handler);
	}

	// Handlers 목록에 있는 함수들 전부 실행
	void Broadcast(Args... args)
	{
		for (int i = 0; i < Handlers.Num();i++)
		{
			Handlers[i](args...);
		}
	}

private:
	TArray<HandlerType> Handlers;
};
