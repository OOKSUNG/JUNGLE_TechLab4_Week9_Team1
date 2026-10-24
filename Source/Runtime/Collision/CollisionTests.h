#pragma once

#include "Core/Types.h"

namespace Collision
{
	// 충돌 도형과 판정 함수를 에디터 없이 검사한다. Debug 빌드의 에디터 시작 시 한 번 실행한다.
	// 실패한 검사는 Error 로그로, 요약은 Info 로그로 남기고 실패 개수를 돌려준다.
	int32 RunSelfTests();
}
