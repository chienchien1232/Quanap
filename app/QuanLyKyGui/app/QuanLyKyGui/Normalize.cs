using System.Text.RegularExpressions;

namespace QuanLyKyGui;

/// <summary>Chuẩn hoá dữ liệu nhập trước khi lưu CSDL.</summary>
internal static class Normalize
{
    /// <summary>
    /// Số điện thoại: bỏ dấu cách, chấm, gạch nối. Giữ nguyên số và dấu + ở đầu.
    /// CSDL có UNIQUE trên cột này nên phải chuẩn hoá để không tạo hai hồ sơ cùng một số.
    /// </summary>
    public static string Phone(string input)
    {
        if (string.IsNullOrWhiteSpace(input)) return string.Empty;
        var digits = Regex.Replace(input.Trim(), @"[ .-]", string.Empty);
        return digits.Length > 0 && digits[0] == '+' ? "+" + digits[1..].Replace("+", "") : digits.Replace("+", "");
    }

    /// <summary>Kiểm tra số điện thoại đã chuẩn hoá: 8–20 ký tự, chỉ số và dấu + ở đầu.</summary>
    public static bool IsValidPhone(string normalized)
    {
        return Regex.IsMatch(normalized, @"\A\+?[0-9]{8,20}\z");
    }

    /// <summary>Email: bỏ khoảng trắng thừa hai đầu và hạ chữ thường phần tên miền.</summary>
    public static string Email(string input)
    {
        var value = input.Trim();
        var at = value.LastIndexOf('@');
        return at > 0 ? value[..at] + value[at..].ToLowerInvariant() : value;
    }
}
