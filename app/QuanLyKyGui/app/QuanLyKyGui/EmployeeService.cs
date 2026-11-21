using System.Data;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace QuanLyKyGui;

internal static class EmployeeService
{
    public static DataTable List() => Db.Query("""
        SELECT nv.MaNV, nv.HoTen, nv.SoDienThoai, nv.Email, nv.ChucVu, nv.TrangThai,
               (SELECT COUNT(*) FROM dbo.PHIEU_KY_GUI p WHERE p.MaNV = nv.MaNV)
             + (SELECT COUNT(*) FROM dbo.DON_HANG d WHERE d.MaNV = nv.MaNV)
             + (SELECT COUNT(*) FROM dbo.PHIEU_THANH_TOAN_KY_GUI t WHERE t.MaNV = nv.MaNV) AS SoNghiepVu
        FROM dbo.NHAN_VIEN nv ORDER BY nv.MaNV;
        """);

    public static int Add(string name, string phone, string email, string role)
    {
        name = name.Trim();
        phone = Normalize.Phone(phone);
        email = Normalize.Email(email);
        if (name.Length is 0 or > 100)
            throw new ArgumentException("Họ tên phải có từ 1 đến 100 ký tự.");
        if (phone.Length > 0 && !Normalize.IsValidPhone(phone))
            throw new ArgumentException("Số điện thoại cần 8–20 chữ số, chỉ gồm số và dấu + ở đầu.");
        if (email.Length > 254 || (email.Length > 0 && !Regex.IsMatch(email, @"\A[^@\s]+@[^@\s]+\.[^@\s]+\z")))
            throw new ArgumentException("Email không đúng định dạng hoặc dài quá 254 ký tự.");
        if (role is not ("Nhân viên" or "Thu ngân" or "Quản lý"))
            throw new ArgumentException("Chức vụ không hợp lệ.");

        return Mutate((cn, tx) =>
        {
            using var cmd = new SqlCommand("""
                INSERT dbo.NHAN_VIEN (HoTen, SoDienThoai, Email, ChucVu, TrangThai)
                OUTPUT INSERTED.MaNV
                VALUES (@Name, @Phone, @Email, @Role, N'Đang làm việc');
                """, cn, tx);
            cmd.Parameters.AddRange(new[] {
                Db.Param("@Name", name), Db.Param("@Phone", phone.Length == 0 ? null : phone),
                Db.Param("@Email", email.Length == 0 ? null : email), Db.Param("@Role", role)
            });
            return Convert.ToInt32(cmd.ExecuteScalar());
        });
    }

    /// <returns>True nếu chuyển Đã nghỉ để giữ lịch sử, false nếu đã xóa hồ sơ chưa có nghiệp vụ.</returns>
    public static bool Remove(int id) => Mutate((cn, tx) =>
    {
        CheckTarget(cn, tx, id);
        using var cmd = new SqlCommand("""
            IF EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI WHERE MaNV = @Id)
                OR EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaNV = @Id)
                OR EXISTS (SELECT 1 FROM dbo.PHIEU_THANH_TOAN_KY_GUI WHERE MaNV = @Id)
            BEGIN
                UPDATE dbo.NHAN_VIEN SET TrangThai = N'Đã nghỉ' WHERE MaNV = @Id;
                SELECT CAST(1 AS bit);
            END
            ELSE
            BEGIN
                DELETE dbo.NHAN_VIEN WHERE MaNV = @Id;
                SELECT CAST(0 AS bit);
            END;
            """, cn, tx);
        cmd.Parameters.Add(Db.Param("@Id", id));
        return Convert.ToBoolean(cmd.ExecuteScalar());
    });

    public static void SetActive(int id, bool active) => Mutate((cn, tx) =>
    {
        CheckTarget(cn, tx, id);
        using var cmd = new SqlCommand(
            "UPDATE dbo.NHAN_VIEN SET TrangThai = @Status WHERE MaNV = @Id", cn, tx);
        cmd.Parameters.AddRange(new[] { Db.Param("@Id", id),
            Db.Param("@Status", active ? "Đang làm việc" : "Đã nghỉ") });
        return cmd.ExecuteNonQuery();
    });

    private static void CheckTarget(SqlConnection cn, SqlTransaction tx, int id)
    {
        if (id == DemoSession.ManagerId)
            throw new InvalidOperationException("Không thể xóa hoặc cho nghỉ quản lý đang thực hiện phiên demo.");
        using var cmd = new SqlCommand(
            "SELECT MaNV FROM dbo.NHAN_VIEN WITH (UPDLOCK, HOLDLOCK) WHERE MaNV = @Id", cn, tx);
        cmd.Parameters.Add(Db.Param("@Id", id));
        if (cmd.ExecuteScalar() is null)
            throw new InvalidOperationException("Nhân viên không còn tồn tại. Hãy làm mới danh sách.");
    }

    private static T Mutate<T>(Func<SqlConnection, SqlTransaction, T> action)
    {
        using var cn = Db.Open();
        using var tx = cn.BeginTransaction();
        using (var check = new SqlCommand("""
            SELECT MaNV FROM dbo.NHAN_VIEN WITH (UPDLOCK, HOLDLOCK)
            WHERE MaNV = @Id AND ChucVu = N'Quản lý' AND TrangThai = N'Đang làm việc';
            """, cn, tx))
        {
            check.Parameters.Add(Db.Param("@Id", DemoSession.ManagerId));
            if (check.ExecuteScalar() is null)
                throw new InvalidOperationException("Phiên demo cần một quản lý đang làm việc. Hãy mở lại ứng dụng.");
        }
        var result = action(cn, tx);
        tx.Commit();
        return result;
    }
}
