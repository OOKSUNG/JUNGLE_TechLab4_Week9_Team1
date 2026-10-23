#pragma once

#include "EnginePCH.h"

#include <functional>
#include "Containers/Array.h"

template<typename... Args>

class TDelegate
{
public:
	using HandlerType = std::function<void(Args...)>;

	
	// 일반 함수나 람다 등록
	void Add(const HandlerType& handler)
	{

	}

	// 클래스 멤버 함수 바인딩
	template<typename T>
	void AddDynamic(T* Instance, void (T::* Func)(Args...))
	{

	}


	void Execute(Args... args)
	{
		
	}

	void Broadcast(Args... args)
	{
		for (int i = 0; i < Handlers.Num();i++)
		{
			Handlers[i](args...);
		}
	}

	template<typename T>
	void Bind(T* Instance, void (T::* Func)(Args...))
	{

	}

private:
	TArray<HandlerType> Handlers;
};


//#define DECLARE_DELEGATE(Name, ...) TDelegate<__VA_ARGS__> Name
//DECLARE_DELEGATE(OnHealthChanged, int);
//DECLARE_DELEGATE(OnTakeDamage, int);
