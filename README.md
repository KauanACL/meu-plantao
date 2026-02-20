# 🏥 MeuPlantão

> App iOS nativo para profissionais de saúde gerenciarem sua escala de plantões, finanças e notificações.

---

## 📌 Sobre o Projeto

O **MeuPlantão** é um aplicativo iOS desenvolvido para profissionais de saúde que trabalham em regime de plantão (médicos, enfermeiros, técnicos etc.). O app centraliza o controle de escalas, pagamentos recebidos e lembretes automáticos, tudo armazenado com segurança no iCloud do usuário.

**Problema que resolve:** Profissionais de saúde gerenciam suas escalas por papel, planilha ou grupos de WhatsApp, sem visibilidade clara sobre quanto vão ganhar ou onde vão trabalhar.

**Solução:** Um app nativo, rápido e seguro que organiza plantões, calcula ganhos e avisa antes de cada turno.

---

## ⚙️ Tecnologias

- **Swift 5** + **SwiftUI**
- **SwiftData** — persistência local
- **CloudKit** — sync seguro via iCloud (dados criptografados pela Apple)
- **UserNotifications** — notificações locais para lembretes de plantão
- **EventKit** — integração com Calendário nativo do iOS
- **Face ID / Touch ID** — autenticação biométrica
- **StoreKit** — assinatura Premium via Apple ID

---

## ✨ Funcionalidades

- Cadastro de plantões com local, data, horário e valor
- Duração configurável (1–36 horas)
- Valor padrão por turno configurável nas preferências
- **Notificações automáticas:** lembrete no dia (2h antes) e 1 dia antes
- **Sincronização com Calendário iOS** — exporta todos os plantões para o app nativo
- Autenticação via **Face ID** para proteção dos dados
- **Resumo financeiro** — total a receber por período
- Histórico de plantões com filtros
- **Plano Premium** com assinatura recorrente via App Store
- Dados armazenados 100% no iCloud do usuário (sem servidor externo)
- Termos de uso e privacidade integrados no app

---

## 🚀 Como Rodar

### Pré-requisitos
- Xcode 16+
- macOS Sequoia ou superior
- Conta Apple Developer (para rodar em dispositivo físico)

```bash
# Clone o repositório
git clone <link-do-repo>

# Abra no Xcode
open MeuPlantão.xcodeproj

# Selecione o simulador ou dispositivo e rode (⌘ + R)
```

> ⚠️ O CloudKit requer conta Apple Developer ativa para funcionar em produção.

---

## 🌐 Links

- 🍎 **App Store:** _em breve_

---

## 📸 Screenshots



---

## 👤 Autor

Desenvolvido por **Kauan** — [LinkedIn](https://www.linkedin.com/in/kauan-acl/)
