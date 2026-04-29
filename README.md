# bidtalk-ios

입찰톡 iOS 앱 저장소입니다.

이 저장소는 사용자의 키워드 등록, 알림 설정, Firebase FCM Topic 구독, 알림 내역 화면을 담당합니다.

## 운영 역할

```text
bidtalk-ios
= iOS 앱
= 키워드 등록 UI
= FCM Topic 구독/해제
= GitHub Actions 스케줄러 없음

g2b-bot
= 운영 알림 워커
= 30분마다 나라장터 조회
= Firebase FCM 발송
= state 갱신
```

실제 입찰공고/사전규격 조회와 푸시 발송은 `off-love/g2b-bot`에서만 수행합니다.
이 저장소의 `.github/workflows/check_notices.yml`은 수동 요청 시 `g2b-bot` 워크플로를 호출하는 용도로만 사용합니다.
수동 호출 기능을 쓰려면 이 저장소에 `G2B_BOT_DISPATCH_TOKEN` secret이 필요합니다.

## 주요 제한

- 사용자당 키워드 최대 3개
- 키워드당 업무구분 1개
- 너무 넓은 키워드 차단
- Firebase FCM Topic 방식 유지
