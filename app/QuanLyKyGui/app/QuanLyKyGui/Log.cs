using System.Diagnostics;
using System.IO;
using System.Text;

namespace QuanLyKyGui;

/// <summary>
/// Ghi log thao tác xuống tệp và cửa sổ Output, kèm tham số đầu vào và kết quả trả về.
/// Dùng khi cần soi một luồng nghiệp vụ mà giao diện không báo lỗi.
/// </summary>
internal static class Log
{
    private static readonly object Gate = new();
    private static readonly string Folder = Path.Combine(AppContext.BaseDirectory, "logs");

    /// <summary>Bắn ra mỗi dòng log vừa ghi, để giao diện hiển thị trực tiếp.</summary>
    public static event Action<string>? Written;

    /// <summary>Đường dẫn tệp log của ngày hôm nay.</summary>
    public static string FilePath
    {
        get
        {
            lock (Gate)
            {
                Directory.CreateDirectory(Folder);
                return Path.Combine(Folder, $"app-{DateTime.Now:yyyyMMdd}.log");
            }
        }
    }

    /// <summary>Ghi một dòng log: nhãn, các cặp đầu vào và kết quả đầu ra.</summary>
    public static void Write(string label, IEnumerable<(string Key, object? Value)>? input = null,
                             IEnumerable<(string Key, object? Value)>? output = null,
                             Exception? error = null)
    {
        var line = new StringBuilder();
        line.Append(DateTime.Now.ToString("HH:mm:ss.fff")).Append(" | ").Append(label);

        if (input is not null)
            line.Append(" | IN ").Append(Format(input));
        if (output is not null)
            line.Append(" | OUT ").Append(Format(output));
        if (error is not null)
            line.Append(" | ERR ").Append(error.GetType().Name).Append(": ").Append(error.Message);

        var text = line.ToString();
        Debug.WriteLine(text);

        try
        {
            lock (Gate)
            {
                File.AppendAllText(FilePath, text + Environment.NewLine, Encoding.UTF8);
            }
        }
        catch
        {
            /* Ghi log không được phép làm hỏng thao tác nghiệp vụ. */
        }

        try
        {
            Written?.Invoke(text);
        }
        catch
        {
            /* Trình hiển thị log cũng không được phép làm hỏng thao tác. */
        }
    }

    /// <summary>Chuỗi mô tả các cặp khoá/giá trị, để hiển thị thẳng cho người dùng.</summary>
    public static string Format(IEnumerable<(string Key, object? Value)> pairs)
    {
        var parts = new List<string>();
        foreach (var (key, value) in pairs)
            parts.Add($"{key}={Describe(value)}");
        return string.Join(", ", parts);
    }

    private static string Describe(object? value) => value switch
    {
        null => "(null)",
        string s => s.Length == 0 ? "(rỗng)" : s,
        DateTime d => d.ToString("dd/MM/yyyy HH:mm:ss"),
        decimal m => m.ToString("#,##0"),
        _ => Convert.ToString(value) ?? "(null)"
    };
}
