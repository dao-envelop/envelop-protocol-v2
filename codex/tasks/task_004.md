# Deep Audit Singleton721 & SmartWallet
## Проблема
Мы  готовим минорный  релиз 2.2.1, губокого аудита не было.

## Что делать.
Read https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain.
Подключи все skill по Ethereum, evm уязвимостям. ищи критичные  баги, которые позволяют
несакнционировано withdarw е активы из smart wallet. Если найдешь, то эмулируй атаку в отдельном файле теста. Елси нужно -сделай mock

## Критерий успеха
найдены уязвимости. сохранены  в отдлеьном файле `./codex/tasks/findings**.md`. Создан юнит тест который
подтверждает такое поведение.