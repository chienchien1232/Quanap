namespace QuanLyKyGui;

/// <summary>Hộp thoại nhập giá và đăng bán một sản phẩm đã được chấp nhận.</summary>
internal sealed class frmDangBanSanPham : Form
{
    private readonly NumericUpDown _numPrice = Theme.Number(Theme.MoneyMax, 220);
    private readonly Label _lblError = new()
    {
        AutoSize = false,
        Dock = DockStyle.Fill,
        Margin = new Padding(0),
        Font = Theme.Small,
        ForeColor = Theme.Danger
    };

    [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
    public decimal Price => Theme.MoneyValue(_numPrice);

    public frmDangBanSanPham(string productName, decimal currentPrice)
    {
        Text = "Đăng bán sản phẩm — Thiên Kim Consignment";
        ClientSize = new Size(480, 320);
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
            RowCount = 5,
            Padding = new Padding(24, 18, 24, 16),
            BackColor = Theme.Canvas
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 66));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 62));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 32));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));

        var titles = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent };
        titles.Controls.Add(new Label
        {
            Text = "Đăng bán sản phẩm",
            Font = Theme.H2,
            ForeColor = Theme.Ink,
            AutoSize = true,
            Location = new Point(0, 0)
        });
        var name = productName.Length > 48 ? productName[..45] + "…" : productName;
        titles.Controls.Add(new Label
        {
            Text = name,
            Font = Theme.Small,
            ForeColor = Theme.Muted,
            AutoSize = true,
            Location = new Point(1, 32)
        });
        root.Controls.Add(titles, 0, 0);
        root.Controls.Add(Fields.Field("Giá đăng bán *", _numPrice), 0, 1);

        if (currentPrice > 0) _numPrice.Value = Math.Min(currentPrice, Theme.PriceMax);
        root.Controls.Add(_lblError, 0, 2);

        var hint = new Label
        {
            Text = "Sau khi đăng bán, sản phẩm chuyển sang trạng thái Đang bán và có thể thêm vào đơn hàng.",
            Font = Theme.Small,
            ForeColor = Theme.Muted,
            AutoSize = false,
            Dock = DockStyle.Fill,
            Margin = new Padding(0, 0, 0, 8)
        };
        root.Controls.Add(hint, 0, 3);

        var cancel = Theme.GhostButton("Hủy", 100);
        cancel.Click += (_, _) => { DialogResult = DialogResult.Cancel; Close(); };
        var save = Theme.PrimaryButton("Xác nhận đăng bán", 190);
        save.Click += (_, _) => Confirm();
        var actions = Theme.Actions(cancel, save);
        actions.Dock = DockStyle.Right;
        actions.Margin = new Padding(0);
        root.Controls.Add(actions, 0, 4);

        Controls.Add(root);
        AcceptButton = save;
        CancelButton = cancel;
        Shown += (_, _) => _numPrice.Focus();
    }

    private void Confirm()
    {
        var price = Theme.MoneyValue(_numPrice);
        if (price <= 0)
        {
            _lblError.Text = "Giá đăng bán phải lớn hơn 0.";
            _numPrice.Focus();
            return;
        }
        if (!Theme.PriceInRange(price, out var error))
        {
            _lblError.Text = error;
            _numPrice.Focus();
            return;
        }
        DialogResult = DialogResult.OK;
        Close();
    }
}
