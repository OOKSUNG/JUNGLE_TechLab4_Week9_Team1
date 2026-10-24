#pragma once

#include"EnginePCH.h"
#include <coroutine>

struct CoroutineInfo
{
	float remainTime{};	// 남은 시간
	std::function<void()> CoroutineFunction;	// Couroutine 대기 완료 후 재개할 함수
	std::function<bool()> CheckFunction;	// 조건 Coroutine사 체크할 함수
};

class CoroutineScheduler
{
public:
	using CoroutineFunc = std::function<void()>;
	using CheckFunc = std::function<bool()>;

	void Wait(CoroutineFunc Function, float Waittime)	// Function은 Coroutine 대기 완료 후 재개할 함수 람다 형태로 추가
	{
		CoroutineInfo Coroutine;
		Coroutine.CoroutineFunction = Function;
		Coroutine.remainTime = Waittime;
		CoroutineInfoArray.Add(Coroutine);	// CouroutineInfoArray에 해당 정보 추가
	}

	void Update(float deltaTime)
	{
		for (int i = 0;i < CoroutineInfoArray.Num();i++) {
			if (CoroutineInfoArray[i].CheckFunction)	// 조건 Coroutine일 경우와 시간 Coroutine일 경우 분리
			{
				if (CoroutineInfoArray[i].CheckFunction())
				{
					std::function<void()> callback = CoroutineInfoArray[i].CoroutineFunction;	// Callback으로 실행
					callback();
					CoroutineInfoArray.RemoveAt(i);	// Callback 실행했으므로 Coroutine 목록에서 제거
				}
			}
			else
			{
				CoroutineInfoArray[i].remainTime -= deltaTime;	// 시간 DeltaTime만큼 감소
				if (CoroutineInfoArray[i].remainTime <= 0)
				{

					std::function<void()> callback = CoroutineInfoArray[i].CoroutineFunction;	// Callback으로 실행
					callback();
					CoroutineInfoArray.RemoveAt(i);	// Callback 실행했으므로 Coroutine 목록에서 제거
				}
			}
		}
	}

	void WaitUntil(CoroutineFunc Function, CheckFunc CheckFunc)
	{
		CoroutineInfo Coroutine;
		Coroutine.CoroutineFunction = Function;
		Coroutine.CheckFunction = CheckFunc;
		CoroutineInfoArray.Add(Coroutine);	// CouroutineInfoArray에 해당 정보 추가
	}

private:
	TArray<CoroutineInfo> CoroutineInfoArray;
};

