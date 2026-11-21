using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyKyGui;

/// <summary>
/// Xử lý các giao dịch thanh toán đang ở trạng thái Chờ xử lý của một đơn hàng.
/// Trước đây giao dịch treo chặn cả việc huỷ đơn mà không có đường thoát trên giao diện.
/// </summary>
internal sealed class frmXuLyGiaoDichTreo : Form
{
    private readonly int _maDh;
    private readonly DataGridView _grid = new();
    private readonly Label _lblMessage = new() { AutoSize = true, Font = Theme.Small, ForeColor = Theme.Muted };
    private readonly TextBox _txtLog = new()
    {
        Multiline = true,
        ReadOnly = true,
        ScrollBars = ScrollBars.Vertical,
        Dock = DockStyle.Fill,
        BorderStyle = BorderStyle.FixedSingle,
        BackColor = Color.FromArgb(250, 248, 244),
        Font = new Font("Consolas", 8.5f),
        WordWrap = false
    };
    private bool _changed;

    [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
    public bool Changed => _changed;

    public frmXuLyGiaoDichTreo(int maDh)
    {
        _maDh = maDh;
        Text = $"Xử lý giao dịch treo — Đơn #{maDh}";
        ClientSize = new Size(760, 420);
        MinimumSize = new Size(680, 380);
        StartPosition = FormStartPosition.CenterParent;
        BackColor = Theme.Canvas;
        Font = Theme.Body;

        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 6,
            Padding = new Padding(20, 16, 20, 14),
            BackColor = Theme.Canvas
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 28));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 150));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 20));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 46));

        var heading = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent };
        heading.Controls.Add(new Label
        {
            Text = "Giao dịch đang chờ xử lý",
            Font = Theme.H2,
            ForeColor = Theme.Ink,
            AutoSize = true,
            Location = new Point(0, 0)
        });
        heading.Controls.Add(new Label
        {
            Text = "Chọn một giao dịch rồi xác nhận kết quả. Giao dịch Thất bại sẽ được đóng lại và không tính vào số tiền đã thu.",
            Font = Theme.Small,
            ForeColor = Theme.Muted,
            AutoSize = true,
            Location = new Point(1, 28)
        });
        root.Controls.Add(heading, 0, 0);

        _grid.Dock = DockStyle.Fill;
        _grid.ReadOnly = true;
        _grid.AutoGenerateColumns = true;
        _grid.AllowUserToAddRows = false;
        _grid.AllowUserToDeleteRows = false;
        _grid.RowHeadersVisible = false;
        _grid.BackgroundColor = Theme.Surface;
        _grid.BorderStyle = BorderStyle.None;
        _grid.Font = Theme.Small;
        _grid.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        _grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        _grid.MultiSelect = false;
        root.Controls.Add(_grid, 0, 1);

        _lblMessage.Margin = new Padding(0, 4, 0, 0);
        root.Controls.Add(_lblMessage, 0, 2);

        _txtLog.Margin = new Padding(0, 4, 0, 0);
        root.Controls.Add(_txtLog, 0, 3);
        root.Controls.Add(new Label
        {
            Text = "Nhật ký thao tác (IN = tham số gửi vào, OUT = kết quả trả về)",
            Font = Theme.Small,
            ForeColor = Theme.Muted,
            Dock = DockStyle.Fill,
            Margin = new Padding(0, 2, 0, 0)
        }, 0, 4);

        var success = Theme.PrimaryButton("Xác nhận Thành công", 190);
        success.Click += (_, _) => Resolve("Thành công");
        var failed = Theme.GhostButton("Đánh dấu Thất bại", 180);
        failed.Click += (_, _) => Resolve("Thất bại");
        var close = Theme.GhostButton("Đóng", 100);
        close.Click += (_, _) => Close();
        var actions = Theme.Actions(failed, success, close);
        actions.Dock = DockStyle.Right;
        actions.Margin = new Padding(0);
        root.Controls.Add(actions, 0, 5);

        Controls.Add(root);
        CancelButton = close;
        Log.Written += AppendLog;
        FormClosed += (_, _) => Log.Written -= AppendLog;
        Load += (_, _) => LoadPending();
    }

    private void AppendLog(string line)
    {
        if (IsDisposed) return;
        if (InvokeRequired)
        {
            BeginInvoke(new Action<string>(AppendLog), line);
            return;
        }
        _txtLog.AppendText(line + Environment.NewLine);
    }

    private void LoadPending()
    {
        try
        {
            var table = Db.Query("""
                SELECT MaTTDH, SoTien, NgayTao, PhuongThuc, MaGiaoDich, GhiChu
                FROM dbo.THANH_TOAN_DON_HANG
                WHERE MaDH = @MaDH AND TrangThai = N'Chờ xử lý'
                ORDER BY MaTTDH;
                """, Db.Param("@MaDH", _maDh));
            _grid.DataSource = table;

            if (_grid.Columns.Contains("MaTTDH")) _grid.Columns["MaTTDH"]!.HeaderText = "Mã GD";
            if (_grid.Columns.Contains("SoTien"))
            {
                _grid.Columns["SoTien"]!.HeaderText = "Số tiền";
                Theme.MoneyColumn(_grid.Columns["SoTien"]!);
            }
            if (_grid.Columns.Contains("NgayTao"))
            {
                _grid.Columns["NgayTao"]!.HeaderText = "Ngày tạo";
                _grid.Columns["NgayTao"]!.DefaultCellStyle.Format = "dd/MM/yyyy HH:mm";
            }
            if (_grid.Columns.Contains("PhuongThuc")) _grid.Columns["PhuongThuc"]!.HeaderText = "Phương thức";
            if (_grid.Columns.Contains("MaGiaoDich")) _grid.Columns["MaGiaoDich"]!.HeaderText = "Mã giao dịch";
            if (_grid.Columns.Contains("GhiChu")) _grid.Columns["GhiChu"]!.HeaderText = "Ghi chú";
            /* Không đặt CurrentCell = null: nếu bỏ chọn thì CurrentRow về null và
               người dùng phải click đúng vào dòng mới bấm được nút. Chọn sẵn dòng
               đầu tiên để thao tác một phát là xong. */
            if (_grid.Rows.Count > 0)
            {
                _grid.CurrentCell = _grid.Rows[0].Cells["MaTTDH"];
                _grid.Rows[0].Selected = true;
            }

            _lblMessage.ForeColor = Theme.Muted;
            _lblMessage.Text = table.Rows.Count == 0
                ? "Đơn hàng này không còn giao dịch nào đang chờ xử lý."
                : $"{table.Rows.Count} giao dịch đang chờ xử lý.";

            var ids = string.Join(",", table.Rows.Cast<DataRow>()
                .Select(r => Convert.ToString(r["MaTTDH"])));
            Log.Write("GD treo: tải danh sách", new (string, object?)[] { ("MaDH", _maDh) },
                new (string, object?)[] { ("SoDong", table.Rows.Count), ("MaTTDH", ids) });
        }
        catch (Exception ex)
        {
            _lblMessage.ForeColor = Theme.Danger;
            _lblMessage.Text = Db.ErrorMessage(ex);
            Log.Write("GD treo: LỖI tải danh sách", new (string, object?)[] { ("MaDH", _maDh) }, error: ex);
        }
    }

    private void Resolve(string target)
    {
        if (_grid.CurrentRow?.DataBoundItem is not DataRowView view)
        {
            _lblMessage.ForeColor = Theme.Danger;
            _lblMessage.Text = "Chọn một giao dịch trong bảng.";
            Log.Write("GD treo: chưa chọn dòng", new (string, object?)[] { ("MucTieu", target) });
            return;
        }

        var id = Convert.ToInt32(view["MaTTDH"]);
        var amount = Convert.ToDecimal(view["SoTien"]);

        Log.Write("GD treo: yêu cầu đổi trạng thái",
            new (string, object?)[] { ("MaTTDH", id), ("MaDH", _maDh), ("SoTien", amount), ("MucTieu", target) });

        var confirm = MessageBox.Show(
            $"Chuyển giao dịch #{id} ({amount:#,##0} đ) sang trạng thái “{target}”?",
            "Xác nhận giao dịch", MessageBoxButtons.YesNo, MessageBoxIcon.Question,
            MessageBoxDefaultButton.Button2);
        if (confirm != DialogResult.Yes)
        {
            Log.Write("GD treo: người dùng huỷ", new (string, object?)[] { ("MaTTDH", id) });
            return;
        }

        try
        {
            using var cn = Db.Open();
            using var cmd = new SqlCommand("dbo.sp_CapNhatThanhToan", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add(Db.Param("@MaTTDH", id));
            cmd.Parameters.Add(Db.Param("@TrangThai", target));
            cmd.Parameters.Add(Db.Param("@GhiChu", "Xử lý tại quầy"));
            var affected = cmd.ExecuteNonQuery();

            var donTrangThai = Convert.ToString(Db.Scalar(
                "SELECT TrangThai FROM dbo.DON_HANG WHERE MaDH = @MaDH", Db.Param("@MaDH", _maDh)));

            Log.Write("GD treo: CSDL đã cập nhật",
                new (string, object?)[] { ("MaTTDH", id), ("MucTieu", target) },
                new (string, object?)[] { ("RowsAffected", affected), ("TrangThaiDon", donTrangThai) });

            _changed = true;
            LoadPending();
        }
        catch (Exception ex)
        {
            _lblMessage.ForeColor = Theme.Danger;
            _lblMessage.Text = Db.ErrorMessage(ex);
            Log.Write("GD treo: LỖI cập nhật",
                new (string, object?)[] { ("MaTTDH", id), ("MucTieu", target) }, error: ex);
        }
    }
}
