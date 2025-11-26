import Foundation

extension Date {
    // Retorna todos os dias do mês atual da data
    func getAllDays() -> [Date] {
        let calendar = Calendar.current
        
        // Pega o início do mês
        let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: self))!
        
        // Descobre quantos dias tem no mês
        let range = calendar.range(of: .day, in: .month, for: startDate)!
        
        // Gera o array de datas
        return range.compactMap { day -> Date in
            return calendar.date(byAdding: .day, value: day - 1, to: startDate)!
        }
    }
    
    // Retorna apenas o dia (1, 2, 30...)
    func format(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    // Verifica se é o mesmo dia que outra data
    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
}
