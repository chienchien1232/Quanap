using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace QuanLyKyGui;

/// <summary>Hộp thoại thêm khách hàng mới, dùng ngay trong màn hình tiếp nhận ký gửi và lập đơn hàng.</summary>
internal sealed class frmKhachHangMoi : Form
{
    private readonly TextBox _txtName = Theme.TextBox(null, 460);
    private readonly TextBox _txtPhone = Theme.TextBox(null, 240);
    private readonly TextBox _txtEmail = Theme.TextBox(null, 460);
    private readonly TextBox _txtAddress = Theme.TextBox(null, 460);
    private readonly Label _lblError = new()
    {
        AutoSize = false,
        Height = 22,
        Width = 460,
        Font = Theme.Small,
        ForeColor = Theme.Danger
    };

    [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
    public int NewCustomerId { get; private set; }

    [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
    public string NewCustomerName { get; private set; } = "";

    public frmKhachHangMoi(string? prefillName = null, string? prefillPhone = null)
    {
        Text = "Thêm khách hàng mới — Thiên Kim Consignment";
        ClientSize = new Size(540, 486);
        MinimumSize = new Size(540, 486);
        MaximumSize = new Size(540, 486);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterParent;
        BackColor = Theme.Canvas;
        Font = Theme.Body;

        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 7,
            Padding = new Padding(24, 18, 24, 16),
            BackColor = Theme.Canvas
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 62));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        var titles = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent };
        titles.Controls.Add(new Label
        {
            Text = "Thêm khách hàng mới",
            Font = Theme.H2,
            ForeColor = Theme.Ink,
            AutoSize = true,
            Location = new Point(0, 0)
        });
        titles.Controls.Add(new Label
        {
            Text = "Khách chưa có trong hệ thống — nhập thông tin để dùng ngay cho phiếu ký gửi hoặc đơn hàng.",
            Font = Theme.Small,
            ForeColor = Theme.Muted,
            AutoSize = true,
            Location = new Point(1, 30)
        });
        root.Controls.Add(titles, 0, 0);

        root.Controls.Add(Fields.Field("Họ tên khách hàng *", _txtName), 0, 1);
        root.Controls.Add(Fields.Field("Số điện thoại *", _txtPhone), 0, 2);
        root.Controls.Add(Fields.Field("Email", _txtEmail), 0, 3);
        root.Controls.Add(Fields.Field("Địa chỉ", _txtAddress), 0, 4);

        _lblError.Margin = new Padding(0, 2, 0, 0);
        root.Controls.Add(_lblError, 0, 5);

        var cancel = Theme.GhostButton("Hủy", 100);
        cancel.Click += (_, _) => { DialogResult = DialogResult.Cancel; Close(); };
        var save = Theme.PrimaryButton("Lưu khách hàng", 170);
        save.Click += (_, _) => SaveCustomer();
        var actions = Theme.Actions(cancel, save);
        actions.Dock = DockStyle.Right;
        root.Controls.Add(actions, 0, 6);

        Controls.Add(root);

        AcceptButton = save;
        CancelButton = cancel;
        _txtName.Text = prefillName ?? "";
        _txtPhone.Text = prefillPhone ?? "";
        Shown += (_, _) => _txtName.Focus();
    }

    private void SaveCustomer()
    {
        var name = _txtName.Text.Trim();
        var phone = Normalize.Phone(_txtPhone.Text);
        var email = Normalize.Email(_txtEmail.Text);
        var address = _txtAddress.Text.Trim();

        if (name.Length == 0)
        {
            ShowError("Họ tên khách hàng không được để trống.");
            _txtName.Focus();
            return;
        }

        if (!Normalize.IsValidPhone(phone))
        {
            ShowError("Số điện thoại phải dài 8–20 chữ số, chỉ gồm số và dấu + ở đầu.");
            _txtPhone.Focus();
            return;
        }

        if (email.Length > 0 && !Regex.IsMatch(email, @"^[^@\s]+@[^@\s]+\.[^@\s]+$"))
        {
            ShowError("Email không đúng định dạng.");
            _txtEmail.Focus();
            return;
        }

        if (Db.Long("SELECT COUNT(*) FROM dbo.KHACH_HANG WHERE SoDienThoai = @Sdt",
                Db.Param("@Sdt", phone)) > 0)
        {
            ShowError("Số điện thoại này đã thuộc một khách hàng khác.");
            _txtPhone.Focus();
            return;
        }

        try
        {
            const string sql = """
                INSERT dbo.KHACH_HANG (HoTen, SoDienThoai, Email, DiaChi)
                OUTPUT INSERTED.MaKH
                VALUES (@HoTen, @SoDienThoai, @Email, @DiaChi);
                """;
            var id = Db.Scalar(sql,
                Db.Param("@HoTen", name),
                Db.Param("@SoDienThoai", phone),
                Db.Param("@Email", email.Length == 0 ? null : email),
                Db.Param("@DiaChi", address.Length == 0 ? null : address));
            NewCustomerId = Convert.ToInt32(id);
            NewCustomerName = name;
            DialogResult = DialogResult.OK;
            Close();
        }
        catch (SqlException ex) when (ex.Number is 2627 or 2601)
        {
            ShowError("Số điện thoại này đã thuộc một khách hàng khác.");
        }
        catch (Exception ex)
        {
            ShowError(Db.ErrorMessage(ex));
        }
    }

    private void ShowError(string message)
    {
        _lblError.Text = message;
        _lblError.ForeColor = Theme.Danger;
    }
}
