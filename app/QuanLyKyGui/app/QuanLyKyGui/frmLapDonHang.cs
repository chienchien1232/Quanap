using System.Data;
using Microsoft.Data.SqlClient;

namespace QuanLyKyGui;

internal sealed class frmLapDonHang : Form
{
    private DataRow? _buyer;
    private readonly RowStyle _infoRow = new(SizeType.Absolute, 294);
    private readonly TableLayoutPanel _infoLayout = new();
    private readonly TableLayoutPanel _buyerLayout = new();
    private readonly TableLayoutPanel _buyerHeading = new() { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, Margin = new Padding(0) };
    private readonly TableLayoutPanel _buyerActions = new() { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, Margin = new Padding(0) };
    private readonly Label _lblBuyerName = new() { Dock = DockStyle.Fill, Font = Theme.H3, ForeColor = Theme.Ink, AutoEllipsis = true };
    private readonly Label _lblBuyerContact = new() { Dock = DockStyle.Fill, Font = Theme.Small, ForeColor = Theme.Muted, AutoEllipsis = true };
    private readonly Button _findBuyer = Theme.GhostButton("Tìm khách hàng", 136);
    private readonly Button _addBuyer = Theme.GhostButton("+ Thêm khách mới", 174);
    private readonly ComboBox _cboEmployee = Theme.Combo(230);
    private readonly DateTimePicker _dtpOrder = Theme.DatePicker(170);
    private readonly DateTimePicker _dtpDue = Theme.DatePicker(170);
    private readonly TextBox _txtNote = Theme.TextBox(null, 260);

    private readonly TextBox _txtSearch = Theme.TextBox(null, 196);
    private readonly DataGridView _gridProducts = new();
    private readonly NumericUpDown _numDiscount = Theme.Number(Theme.PriceMax, 110);
    private readonly Label _lblProductCount = new() { AutoSize = true, Font = Theme.Small, ForeColor = Theme.Muted };

    private readonly DataGridView _gridDraft = new();
    private readonly DataTable _draft;
    private readonly Label _lblTotal = new() { AutoSize = true, Font = new Font("Segoe UI Semibold", 12f), ForeColor = Theme.Accent };
    private readonly Label _lblDraftError = new() { AutoSize = true, Font = Theme.Small, ForeColor = Theme.Danger };

    private readonly DataGridView _gridOrders = new();
    private readonly Label _lblOrderInfo = new() { Dock = DockStyle.Fill, Font = Theme.Small, ForeColor = Theme.Ink };
    private readonly Label _lblSelectedOrder = new() { Dock = DockStyle.Fill, Font = Theme.Bold, ForeColor = Theme.Accent, AutoEllipsis = true };
    private readonly Label _lblOrderMessage = new() { Dock = DockStyle.Fill, Font = Theme.Small, ForeColor = Theme.Muted };
    private readonly TableLayoutPanel _paymentFields = new();
    private readonly Button _payButton = Theme.PrimaryButton("Thu tiền", 120);
    private readonly Button _completeButton = Theme.GoldButton("Hoàn tất đơn", 140);
    private readonly Button _cancelButton = Theme.GhostButton("Hủy đơn", 100);
    private readonly Button _pendingButton = Theme.GhostButton("Giao dịch treo", 150);
    private bool _loadingOrders;
    private readonly NumericUpDown _numPay = Theme.Number(Theme.MoneyMax, 120);
    private readonly ComboBox _cboMethod = Theme.Combo(104);
    private readonly ComboBox _cboPayStatus = Theme.Combo(104);
    private readonly TextBox _txtTxn = Theme.TextBox(null, 120);
    private readonly TextBox _txtPayNote = Theme.TextBox(null, 150);
    private readonly TextBox _txtCancelReason = Theme.TextBox(null, 170);

    private (int MaDH, decimal TongTien, decimal DaThu, decimal ConLai, string TrangThai)? _selected;

    public frmLapDonHang()
    {
        Text = "Lập đơn hàng & thu tiền — Thiên Kim Consignment";
        ClientSize = new Size(1360, 880);
        MinimumSize = new Size(1180, 740);
        StartPosition = FormStartPosition.CenterParent;
        BackColor = Theme.Canvas;
        Font = Theme.Body;

        _draft = new DataTable();
        _draft.Columns.Add("MaSP", typeof(int));
        _draft.Columns.Add("TenSP", typeof(string));
        _draft.Columns.Add("KichThuoc", typeof(string));
        _draft.Columns.Add("GiaDangBan", typeof(decimal));
        _draft.Columns.Add("GiamGia", typeof(decimal));
        _draft.Columns.Add("ThanhTien", typeof(decimal), "GiaDangBan - GiamGia");

        BuildUi();
        LoadLookups();
        LoadProducts();
        LoadOrders();
        Shown += (_, _) =>
        {
            _gridOrders.ClearSelection();
            _gridOrders.CurrentCell = null;
            ShowSelectedOrder();
            _findBuyer.Focus();
        };
    }

    private void BuildUi()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            Padding = new Padding(20, 14, 20, 14),
            BackColor = Theme.Canvas
        };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 72));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.Controls.Add(BuildTitle(), 0, 0);

        var body = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, Margin = new Padding(0) };
        body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 38));
        body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 62));
        body.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        var left = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Margin = new Padding(0, 0, 14, 0) };
        left.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        left.RowStyles.Add(_infoRow);
        left.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        left.Controls.Add(BuildInfoCard(), 0, 0);
        left.Controls.Add(BuildDraftCard(), 0, 1);
        body.Controls.Add(left, 0, 0);
        body.Controls.Add(BuildProcessColumn(), 1, 0);
        root.Controls.Add(body, 0, 1);
        Controls.Add(root);
    }

    private Control BuildTitle()
    {
        var row = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, Margin = new Padding(0) };
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        var titles = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent };
        titles.Controls.Add(new Label
        {
            Text = "Lập đơn hàng & thu tiền",
            Font = Theme.H1,
            ForeColor = Theme.Ink,
            AutoSize = true,
            Location = new Point(0, 0)
        });
        titles.Controls.Add(new Label
        {
            Text = "Chọn sản phẩm đang bán → giữ hàng → ghi nhận thanh toán → hoàn tất hoặc hủy đơn.",
            Font = Theme.Small,
            ForeColor = Theme.Muted,
            AutoSize = true,
            Location = new Point(2, 40)
        });
        row.Controls.Add(titles, 0, 0);

        var close = Theme.GhostButton("Đóng", 100);
        close.Click += (_, _) => Close();
        var reload = Theme.GhostButton("↻  Làm mới", 120);
        reload.Click += (_, _) =>
        {
            LoadProducts();
            LoadOrders(_selected?.MaDH);
        };
        var actions = Theme.Actions(close, reload);
        row.Controls.Add(actions, 1, 0);
        return row;
    }

    private Control BuildInfoCard()
    {
        var card = new Card("1. Thông tin đơn hàng") {
            Dock = DockStyle.Fill, Margin = new Padding(0, 0, 0, 12), Padding = new Padding(16, 44, 16, 14)
        };
        var viewport = new Panel { Dock = DockStyle.Fill, AutoScroll = true, Margin = new Padding(0) };
        _infoLayout.Dock = DockStyle.Top;
        _infoLayout.ColumnCount = 1;
        _infoLayout.RowCount = 3;
        _infoLayout.Margin = new Padding(0);
        _infoLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        _infoLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 106));
        _infoLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 64));
        _infoLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 64));

        _buyerLayout.Dock = DockStyle.Fill;
        _buyerLayout.ColumnCount = 1;
        _buyerLayout.RowCount = 4;
        _buyerLayout.BackColor = Theme.Canvas;
        _buyerLayout.Padding = new Padding(12, 10, 12, 10);
        _buyerLayout.Margin = new Padding(0, 0, 0, 16);
        _buyerLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        foreach (var height in new[] { 36, 0, 0, 40 })
            _buyerLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, height));
        var buyerHeading = _buyerHeading;
        buyerHeading.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        buyerHeading.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 136));
        buyerHeading.Controls.Add(new Label { Text = "Khách hàng mua", Dock = DockStyle.Fill, Font = Theme.Bold,
            ForeColor = Theme.Ink, TextAlign = ContentAlignment.MiddleLeft, Margin = new Padding(0) }, 0, 0);
        _findBuyer.Dock = DockStyle.Fill;
        _findBuyer.Margin = new Padding(4, 0, 0, 4);
        _findBuyer.ForeColor = Theme.Accent;
        _findBuyer.Click += (_, _) => FindBuyer();
        buyerHeading.Controls.Add(_findBuyer, 1, 0);
        _buyerLayout.Controls.Add(buyerHeading, 0, 0);
        _lblBuyerName.Margin = new Padding(0, 4, 0, 0);
        _lblBuyerContact.Margin = new Padding(0, 2, 0, 0);
        _buyerLayout.Controls.Add(_lblBuyerName, 0, 1);
        _buyerLayout.Controls.Add(_lblBuyerContact, 0, 2);
        _buyerActions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        _buyerActions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        _addBuyer.Dock = DockStyle.Fill;
        _addBuyer.Margin = new Padding(0);
        _addBuyer.Click += (_, _) => AddCustomer();
        _buyerActions.Controls.Add(_addBuyer, 1, 0);
        _buyerLayout.Controls.Add(_buyerActions, 0, 3);
        _infoLayout.Controls.Add(_buyerLayout, 0, 0);

        var employeeAndDate = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, Margin = new Padding(0) };
        employeeAndDate.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        employeeAndDate.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        _cboEmployee.DropDownWidth = 280;
        var employee = OrderInfoField("Nhân viên lập đơn", _cboEmployee);
        employee.Margin = new Padding(0, 0, 12, 8);
        employeeAndDate.Controls.Add(employee, 0, 0);
        employeeAndDate.Controls.Add(OrderInfoField("Ngày lập", _dtpOrder), 1, 0);
        _infoLayout.Controls.Add(employeeAndDate, 0, 1);
        var dueAndNote = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, Margin = new Padding(0) };
        dueAndNote.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        dueAndNote.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        var due = OrderInfoField("Hạn thanh toán", _dtpDue);
        due.Margin = new Padding(0, 0, 12, 8);
        dueAndNote.Controls.Add(due, 0, 0);
        dueAndNote.Controls.Add(OrderInfoField("Ghi chú", _txtNote), 1, 0);
        _infoLayout.Controls.Add(dueAndNote, 0, 2);
        viewport.Controls.Add(_infoLayout);
        card.Body.Controls.Add(viewport);
        UpdateBuyerInfo();
        return card;
    }

    private static Control OrderInfoField(string title, Control input)
    {
        var field = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Margin = new Padding(0, 0, 0, 8) };
        field.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        field.RowStyles.Add(new RowStyle(SizeType.Absolute, 22));
        field.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        field.Controls.Add(new Label { Text = title, Dock = DockStyle.Fill, Font = Theme.Bold,
            ForeColor = Theme.Ink, Margin = new Padding(0) }, 0, 0);
        input.Dock = DockStyle.Fill;
        input.Margin = new Padding(0, 3, 0, 0);
        field.Controls.Add(input, 0, 1);
        return field;
    }
    private Control BuildDraftCard()
    {
        var card = new Card("2. Đơn hàng nháp");
        card.Dock = DockStyle.Fill;
        card.Margin = new Padding(0);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Margin = new Padding(0) };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 76));

        Theme.StyleGrid(_gridDraft);
        _gridDraft.Dock = DockStyle.Fill;
        _gridDraft.AutoGenerateColumns = false;
        _gridDraft.Columns.Add(Theme.TextColumn("TenSP", "Sản phẩm", 170));
        _gridDraft.Columns.Add(Theme.TextColumn("KichThuoc", "Size", 50));
        _gridDraft.Columns.Add(Theme.TextColumn("GiaDangBan", "Giá niêm yết", 95, true));
        _gridDraft.Columns.Add(Theme.TextColumn("GiamGia", "Giảm giá", 85, true));
        _gridDraft.Columns.Add(Theme.TextColumn("ThanhTien", "Thành tiền", 95, true));
        _gridDraft.DataSource = _draft;
        layout.Controls.Add(_gridDraft, 0, 0);

        var footer = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Margin = new Padding(0) };
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        footer.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));
        footer.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        var totals = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Dock = DockStyle.Fill };
        totals.Controls.Add(_lblTotal);
        _lblDraftError.AutoSize = false;
        _lblDraftError.Width = 220;
        _lblDraftError.Height = 20;
        _lblDraftError.AutoEllipsis = true;
        _lblDraftError.Margin = new Padding(12, 2, 0, 0);
        totals.Controls.Add(_lblDraftError);
        footer.Controls.Add(totals, 0, 0);
        var clear = Theme.GhostButton("Xóa dòng", 100);
        clear.Click += (_, _) => RemoveDraftLine();
        var create = Theme.PrimaryButton("Tạo đơn hàng", 160);
        create.Click += (_, _) => CreateOrderFromUi();
        var buttons = Theme.Actions(clear, create);
        buttons.Dock = DockStyle.Right;
        footer.Controls.Add(buttons, 0, 1);
        layout.Controls.Add(footer, 0, 1);

        card.Body.Controls.Add(layout);
        UpdateTotal();
        return card;
    }

    private Control BuildProcessColumn()
    {
        var column = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Margin = new Padding(0) };
        column.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        column.RowStyles.Add(new RowStyle(SizeType.Absolute, 266));
        column.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        column.Controls.Add(BuildPickerCard(), 0, 0);
        column.Controls.Add(BuildOrdersCard(), 0, 1);
        return column;
    }

    private Control BuildPickerCard()
    {
        var card = new Card("3. Sản phẩm đang bán");
        card.Dock = DockStyle.Fill;
        card.Margin = new Padding(0, 0, 0, 12);
        card.Padding = new Padding(16, 40, 16, 8);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3, Margin = new Padding(0) };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 36));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 42));

        var searchRow = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false, Margin = new Padding(0) };
        _txtSearch.Width = 250;
        _txtSearch.PlaceholderText = "Lọc theo tên sản phẩm";
        _txtSearch.TextChanged += (_, _) => LoadProducts();
        _txtSearch.KeyDown += (_, e) =>
        {
            if (e.KeyCode == Keys.Enter)
            {
                e.SuppressKeyPress = true;
                LoadProducts();
            }
        };
        searchRow.Controls.Add(_txtSearch);
        var find = Theme.GhostButton("Tìm", 64);
        find.Margin = new Padding(6, 3, 8, 0);
        find.Click += (_, _) => LoadProducts();
        searchRow.Controls.Add(find);
        _lblProductCount.Margin = new Padding(6, 10, 0, 0);
        searchRow.Controls.Add(_lblProductCount);
        layout.Controls.Add(searchRow, 0, 0);

        Theme.StyleGrid(_gridProducts);
        _gridProducts.Dock = DockStyle.Fill;
        _gridProducts.Margin = new Padding(0, 4, 0, 4);
        _gridProducts.CellDoubleClick += (_, e) =>
        {
            if (e.RowIndex >= 0) AddSelectedProduct();
        };
        layout.Controls.Add(_gridProducts, 0, 1);

        var addRow = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false, Margin = new Padding(0) };
        addRow.Controls.Add(new Label
        {
            Text = "Giảm giá",
            AutoSize = true,
            Font = Theme.Small,
            ForeColor = Theme.Muted,
            Margin = new Padding(0, 11, 8, 0)
        });
        _numDiscount.Margin = new Padding(0, 6, 8, 0);
        addRow.Controls.Add(_numDiscount);
        var add = Theme.GoldButton("+  Thêm vào đơn", 160);
        add.Margin = new Padding(0, 4, 8, 0);
        add.Click += (_, _) => AddSelectedProduct();
        addRow.Controls.Add(add);
        addRow.Controls.Add(new Label
        {
            Text = "Nhấp đúp dòng sản phẩm để thêm nhanh.",
            AutoSize = true,
            Font = Theme.Small,
            ForeColor = Theme.Muted,
            Margin = new Padding(10, 11, 0, 0)
        });
        layout.Controls.Add(addRow, 0, 2);

        card.Body.Controls.Add(layout);
        return card;
    }

    private Control BuildOrdersCard()
    {
        var card = new Card("4. Đơn hàng gần đây & xử lý thanh toán") {
            Dock = DockStyle.Fill, Margin = new Padding(0), Padding = new Padding(16, 40, 16, 8)
        };
        // Bảng đơn có thanh cuộn riêng; cả khu vực cũng cuộn khi cửa sổ thấp.
        var viewport = new Panel { Dock = DockStyle.Fill, AutoScroll = true, Margin = new Padding(0) };
        var layout = new TableLayoutPanel {
            Dock = DockStyle.Top, Height = 500, ColumnCount = 1, RowCount = 4, Margin = new Padding(0)
        };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 26));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 12));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 310));
        layout.Controls.Add(new Label {
            Text = "Chọn hóa đơn cần thanh toán", Dock = DockStyle.Fill, Font = Theme.Bold, ForeColor = Theme.Ink
        }, 0, 0);
        Theme.StyleGrid(_gridOrders);
        _gridOrders.Dock = DockStyle.Fill;
        _gridOrders.Margin = new Padding(0);
        _gridOrders.MultiSelect = false;
        _gridOrders.ScrollBars = ScrollBars.Both;
        _gridOrders.AutoSizeRowsMode = DataGridViewAutoSizeRowsMode.None;
        _gridOrders.SelectionChanged += (_, _) => ShowSelectedOrder();
        _gridOrders.CurrentCellChanged += (_, _) => ShowSelectedOrder();
        layout.Controls.Add(_gridOrders, 0, 1);

        var payment = new Panel {
            Dock = DockStyle.Fill, BorderStyle = BorderStyle.FixedSingle, BackColor = Theme.Surface,
            Padding = new Padding(10), Margin = new Padding(0)
        };
        var paymentLayout = new TableLayoutPanel {
            Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5, Margin = new Padding(0)
        };
        paymentLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        paymentLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 62));
        paymentLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 112));
        paymentLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        paymentLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 36));
        paymentLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        var banner = new TableLayoutPanel {
            Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, BackColor = Theme.AccentSoft,
            Padding = new Padding(8, 4, 8, 4), Margin = new Padding(0, 0, 0, 6)
        };
        banner.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        banner.RowStyles.Add(new RowStyle(SizeType.Absolute, 22));
        banner.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        banner.Controls.Add(_lblSelectedOrder, 0, 0);
        banner.Controls.Add(_lblOrderInfo, 0, 1);
        paymentLayout.Controls.Add(banner, 0, 0);

        _paymentFields.Dock = DockStyle.Fill;
        _paymentFields.ColumnCount = 3;
        _paymentFields.RowCount = 2;
        _paymentFields.Margin = new Padding(0);
        for (var i = 0; i < 3; i++) _paymentFields.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f / 3));
        for (var i = 0; i < 2; i++) _paymentFields.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
        _cboMethod.Items.AddRange(new object[] { "Tiền mặt", "Chuyển khoản", "Thẻ", "Ví điện tử" });
        _cboMethod.SelectedIndex = 0;
        _cboPayStatus.Items.AddRange(new object[] { "Thành công", "Chờ xử lý", "Thất bại" });
        _cboPayStatus.SelectedIndex = 0;
        _paymentFields.Controls.Add(PaymentField("Số tiền thu", _numPay), 0, 0);
        _paymentFields.Controls.Add(PaymentField("Phương thức", _cboMethod), 1, 0);
        _paymentFields.Controls.Add(PaymentField("Kết quả giao dịch", _cboPayStatus), 2, 0);
        _paymentFields.Controls.Add(PaymentField("Mã giao dịch", _txtTxn), 0, 1);
        var note = PaymentField("Ghi chú thanh toán", _txtPayNote);
        _paymentFields.Controls.Add(note, 1, 1);
        _paymentFields.SetColumnSpan(note, 2);
        paymentLayout.Controls.Add(_paymentFields, 0, 1);

        var actions = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 4, RowCount = 1, Margin = new Padding(0) };
        for (var i = 0; i < 4; i++) actions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 25));
        var buttons = new[] { _payButton, _completeButton, _pendingButton, _cancelButton };
        for (var i = 0; i < buttons.Length; i++) {
            buttons[i].Dock = DockStyle.Fill;
            buttons[i].Margin = new Padding(0, 2, i == buttons.Length - 1 ? 0 : 8, 4);
            actions.Controls.Add(buttons[i], i, 0);
        }
        _payButton.Click += (_, _) => RecordPayment();
        _completeButton.Click += (_, _) => CompleteOrder();
        _pendingButton.Click += (_, _) => ResolvePendingPayments();
        _cancelButton.Click += (_, _) => CancelOrder();
        paymentLayout.Controls.Add(actions, 0, 2);
        var cancelRow = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, Margin = new Padding(0) };
        cancelRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 86));
        cancelRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        cancelRow.Controls.Add(new Label { Text = "Lý do hủy", Dock = DockStyle.Fill, Font = Theme.Small,
            ForeColor = Theme.Muted, TextAlign = ContentAlignment.MiddleLeft }, 0, 0);
        _txtCancelReason.Dock = DockStyle.Fill;
        _txtCancelReason.Margin = new Padding(0, 6, 0, 0);
        cancelRow.Controls.Add(_txtCancelReason, 1, 0);
        paymentLayout.Controls.Add(cancelRow, 0, 3);
        paymentLayout.Controls.Add(_lblOrderMessage, 0, 4);
        payment.Controls.Add(paymentLayout);
        layout.Controls.Add(payment, 0, 3);
        viewport.Controls.Add(layout);
        viewport.ClientSizeChanged += (_, _) => layout.Height = Math.Max(500, viewport.ClientSize.Height);
        card.Body.Controls.Add(viewport);
        return card;
    }

    private static Control PaymentField(string title, Control input)
    {
        var field = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Margin = new Padding(0, 0, 8, 4) };
        field.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        field.RowStyles.Add(new RowStyle(SizeType.Absolute, 20));
        field.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        field.Controls.Add(new Label { Text = title, Dock = DockStyle.Fill, Font = Theme.Small, ForeColor = Theme.Muted }, 0, 0);
        input.Dock = DockStyle.Fill;
        input.Margin = new Padding(0);
        field.Controls.Add(input, 0, 1);
        return field;
    }
    private void UpdateBuyerInfo()
    {
        _lblBuyerName.Text = _buyer is null ? "" : $"{_buyer["HoTen"]} — KH{_buyer["MaKH"]}";
        var selected = _buyer is not null;
        if (selected)
        {
            _buyerHeading.ColumnStyles[1].Width = 136;
            _buyerHeading.Controls.Add(_findBuyer, 1, 0);
            _findBuyer.Margin = new Padding(4, 0, 0, 4);
        }
        else
        {
            _buyerHeading.ColumnStyles[1].Width = 0;
            _buyerActions.Controls.Add(_findBuyer, 0, 0);
            _findBuyer.Margin = new Padding(0, 0, 8, 0);
        }
        _lblBuyerName.Visible = selected;
        _lblBuyerContact.Visible = selected;
        _buyerLayout.RowStyles[1].Height = selected ? _lblBuyerName.Font.Height + 8 : 0;
        _buyerLayout.RowStyles[2].Height = selected ? _lblBuyerContact.Font.Height * 3 + 12 : 0;
        _buyerLayout.RowStyles[3].Height = selected ? 0 : Math.Max(36, _findBuyer.Font.Height + 18);
        var buyerHeight = _buyerLayout.RowStyles.Cast<RowStyle>().Sum(row => row.Height) + _buyerLayout.Margin.Vertical + _buyerLayout.Padding.Vertical;
        _infoLayout.RowStyles[0].Height = buyerHeight;
        _infoLayout.Height = (int)Math.Ceiling(_infoLayout.RowStyles.Cast<RowStyle>().Sum(row => row.Height));
        var card = _infoLayout.Parent?.Parent?.Parent;
        _infoRow.Height = _infoLayout.Height + (card?.Padding.Vertical ?? 52) + (card?.Margin.Vertical ?? 12);
        _findBuyer.Text = _buyer is null ? "Tìm khách hàng" : "Đổi khách";
        _addBuyer.Visible = _buyer is null;
        if (_buyer is DataRow buyer)
        {
            string Value(string column) => string.IsNullOrWhiteSpace(Convert.ToString(buyer[column]))
                ? "Chưa cập nhật" : Convert.ToString(buyer[column])!;
            _lblBuyerContact.Text = $"Điện thoại: {Value("SoDienThoai")}\r\nEmail: {Value("Email")}\r\nĐịa chỉ: {Value("DiaChi")}";
        }
        else _lblBuyerContact.Text = "";
    }

    private void FindBuyer()
    {
        int? currentId = _buyer is null ? null : Convert.ToInt32(_buyer["MaKH"]);
        using var dialog = new frmChonKhachHang(currentId, "khách hàng mua");
        var ownerWindow = Parent?.FindForm() ?? FindForm();
        var result = ownerWindow is null ? dialog.ShowDialog() : dialog.ShowDialog(ownerWindow);
        if (result != DialogResult.OK || dialog.SelectedCustomer is null) return;
        _buyer = dialog.SelectedCustomer;
        UpdateBuyerInfo();
    }

    private void AddCustomer()
    {
        using var dialog = new frmKhachHangMoi();
        var ownerWindow = Parent?.FindForm() ?? FindForm();
        var result = ownerWindow is null ? dialog.ShowDialog() : dialog.ShowDialog(ownerWindow);
        if (result != DialogResult.OK) return;
        try
        {
            var customers = Db.Query("SELECT MaKH, HoTen, SoDienThoai, Email, DiaChi FROM dbo.KHACH_HANG WHERE MaKH = @Id",
                Db.Param("@Id", dialog.NewCustomerId));
            if (customers.Rows.Count == 0)
                throw new InvalidOperationException("Hồ sơ vừa tạo không còn tồn tại. Hãy tìm và chọn lại khách hàng.");
            _buyer = customers.Rows[0];
            UpdateBuyerInfo();
        }
        catch (Exception ex) { _lblDraftError.Text = "Đã tạo khách nhưng chưa tải được hồ sơ: " + Db.ErrorMessage(ex); }
    }
    private void LoadLookups()
    {
        try
        {


            var employees = Db.Query("SELECT MaNV, HoTen, ChucVu FROM dbo.NHAN_VIEN WHERE TrangThai = N'Đang làm việc' ORDER BY HoTen");
            var ev = employees.Copy();
            ev.Columns.Add("HienThi", typeof(string));
            foreach (DataRow row in ev.Rows) row["HienThi"] = $"{row["HoTen"]} ({row["ChucVu"]})";
            _cboEmployee.DataSource = ev;
            _cboEmployee.DisplayMember = "HienThi";
            _cboEmployee.ValueMember = "MaNV";
            DemoSession.SelectManager(_cboEmployee);

            _dtpOrder.Value = DateTime.Now;
            _dtpDue.Value = DateTime.Now.AddDays(3);
        }
        catch (Exception ex)
        {
            MessageBox.Show("Không tải được danh mục: " + Db.ErrorMessage(ex), "Lỗi", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void LoadProducts()
    {
        try
        {
            var key = _txtSearch.Text.Trim();
            var table = Db.Query(@"
SELECT MaSP, TenSP, TenDanhMuc, KichThuoc, TenNguoiKyGui, GiaDangBan
FROM dbo.vw_SanPham_DayDu
WHERE TrangThaiBan = N'Đang bán'
  AND (@Key = N'' OR TenSP LIKE N'%' + @Key + N'%' OR TenNguoiKyGui LIKE N'%' + @Key + N'%' OR TenThuongHieu LIKE N'%' + @Key + N'%')
ORDER BY NgayDangBan DESC, MaSP DESC;", Db.Param("@Key", key));
            _gridProducts.DataSource = table;
            Grid.Bind(_gridProducts, table, new Dictionary<string, string>
            {
                ["TenSP"] = "Sản phẩm",
                ["TenDanhMuc"] = "Danh mục",
                ["KichThuoc"] = "Size",
                ["TenNguoiKyGui"] = "Người ký gửi",
                ["GiaDangBan"] = "Giá đăng bán"
            });
            Theme.MoneyColumn(_gridProducts.Columns["GiaDangBan"]);
            _gridProducts.Columns["MaSP"].FillWeight = 48;
            _gridProducts.Columns["TenSP"].FillWeight = 185;
            _gridProducts.Columns["TenDanhMuc"].FillWeight = 90;
            _gridProducts.Columns["KichThuoc"].FillWeight = 55;
            _gridProducts.Columns["TenNguoiKyGui"].FillWeight = 125;
            _gridProducts.Columns["GiaDangBan"].FillWeight = 98;
            _lblProductCount.Text = $"{table.Rows.Count} sản phẩm đang bán";
        }
        catch (Exception ex)
        {
            SetOrderMessage("Không tải được sản phẩm: " + Db.ErrorMessage(ex), true);
        }
    }

    private void LoadOrders(int? selectId = null)
    {
        try
        {
            _loadingOrders = true;
            _lblOrderMessage.Text = "";
            var table = Db.Query(@"
SELECT MaDH, TenKhachHang, NgayLap, TrangThai, TongTien, DaThu, ConLai
FROM dbo.vw_DonHang_TongHop
ORDER BY NgayLap DESC, MaDH DESC;");
            Grid.Bind(_gridOrders, table, new Dictionary<string, string> {
                ["MaDH"] = "Mã đơn", ["TenKhachHang"] = "Khách hàng", ["TrangThai"] = "Trạng thái",
                ["TongTien"] = "Tổng tiền", ["ConLai"] = "Còn lại"
            }, "NgayLap", "DaThu");
            foreach (var name in new[] { "TongTien", "ConLai" }) Theme.MoneyColumn(_gridOrders.Columns[name]);
            _gridOrders.Columns["MaDH"]!.FillWeight = 65;
            _gridOrders.Columns["TenKhachHang"]!.FillWeight = 175;
            _gridOrders.Columns["TrangThai"]!.FillWeight = 125;
            _gridOrders.Columns["TongTien"]!.FillWeight = 100;
            _gridOrders.Columns["ConLai"]!.FillWeight = 100;
            _gridOrders.ClearSelection();
            _gridOrders.CurrentCell = null;
            if (selectId.HasValue)
                foreach (DataGridViewRow row in _gridOrders.Rows)
                    if (Convert.ToInt32(row.Cells["MaDH"].Value) == selectId.Value) {
                        _gridOrders.CurrentCell = row.Cells["MaDH"];
                        row.Selected = true;
                        _gridOrders.FirstDisplayedScrollingRowIndex = row.Index;
                        break;
                    }
        }
        catch (Exception ex)
        {
            _gridOrders.DataSource = null;
            SetOrderMessage("Không tải được đơn hàng: " + Db.ErrorMessage(ex), true);
        }
        finally { _loadingOrders = false; }
        ShowSelectedOrder();
    }

    private void ShowSelectedOrder()
    {
        if (_loadingOrders) return;
        if (_gridOrders.CurrentRow?.DataBoundItem is not DataRowView view)
        {
            _selected = null;
            _lblSelectedOrder.Text = "Chưa chọn đơn hàng";
            _lblOrderInfo.Text = "Chọn một hóa đơn trong bảng phía trên để xem và xử lý thanh toán.";
            _numPay.Value = 0;
            _paymentFields.Enabled = false;
            _payButton.Enabled = _completeButton.Enabled = _cancelButton.Enabled = false;
            _pendingButton.Enabled = false;
            _txtCancelReason.Enabled = false;
            return;
        }
        var row = view.Row;
        var id = Convert.ToInt32(row["MaDH"]);
        var total = Convert.ToDecimal(row["TongTien"]);
        var paid = Convert.ToDecimal(row["DaThu"]);
        var remain = Convert.ToDecimal(row["ConLai"]);
        var status = Convert.ToString(row["TrangThai"]) ?? "";
        var changed = _selected?.MaDH != id;
        _selected = (id, total, paid, remain, status);
        _lblSelectedOrder.Text = $"Đang chọn đơn #{id} — Khách hàng: {row["TenKhachHang"]}";
        _lblOrderInfo.Text = $"{status}  •  Tổng: {total:#,##0} đ  •  Đã thu: {paid:#,##0} đ  •  Còn lại: {remain:#,##0} đ";
        var canPay = status == "Chờ thanh toán" && remain > 0;
        _paymentFields.Enabled = canPay;
        _payButton.Enabled = canPay;
        _completeButton.Enabled = status == "Đang xử lý" && paid >= total;
        _cancelButton.Enabled = status == "Chờ thanh toán" && paid == 0;
        _pendingButton.Enabled = Db.Long(
            "SELECT COUNT(*) FROM dbo.THANH_TOAN_DON_HANG WHERE MaDH = @MaDH AND TrangThai = N'Chờ xử lý'",
            Db.Param("@MaDH", id)) > 0;
        _txtCancelReason.Enabled = _cancelButton.Enabled;
        if (changed)
        {
            _txtTxn.Clear();
            _txtPayNote.Clear();
            _txtCancelReason.Clear();
            _lblOrderMessage.Text = "";
        }
        if (!canPay) _numPay.Value = 0;
        else if (changed || _numPay.Value == 0) _numPay.Value = Math.Min(Theme.MoneyMax, remain);
    }
    private void AddSelectedProduct()
    {
        _lblDraftError.Text = string.Empty;
        if (_gridProducts.CurrentRow is null)
        {
            _lblDraftError.Text = "Chọn một sản phẩm trong danh sách đang bán.";
            return;
        }

        var row = _gridProducts.CurrentRow;
        var maSp = Convert.ToInt32(row.Cells["MaSP"].Value);
        var name = Convert.ToString(row.Cells["TenSP"].Value) ?? "";
        var size = Convert.ToString(row.Cells["KichThuoc"].Value) ?? "";
        var price = Convert.ToDecimal(row.Cells["GiaDangBan"].Value);
        var discount = Theme.MoneyValue(_numDiscount);

        if (_draft.Rows.Cast<DataRow>().Any(x => Convert.ToInt32(x["MaSP"]) == maSp))
        {
            _lblDraftError.Text = "Sản phẩm này đã có trong đơn nháp.";
            return;
        }
        if (discount * 2 > price)
        {
            _lblDraftError.Text = "Giảm giá không được vượt quá 50% giá niêm yết.";
            return;
        }

        var newRow = _draft.NewRow();
        newRow["MaSP"] = maSp;
        newRow["TenSP"] = name;
        newRow["KichThuoc"] = size;
        newRow["GiaDangBan"] = price;
        newRow["GiamGia"] = discount;
        _draft.Rows.Add(newRow);
        _numDiscount.Value = 0;
        UpdateTotal();
    }

    private void RemoveDraftLine()
    {
        if (_gridDraft.CurrentRow?.DataBoundItem is DataRowView view)
        {
            _draft.Rows.Remove(view.Row);
            UpdateTotal();
        }
    }

    private void UpdateTotal()
    {
        var total = _draft.Rows.Cast<DataRow>().Sum(r => Convert.ToDecimal(r["ThanhTien"]));
        _lblTotal.Text = $"Tổng cộng: {total:#,##0} đ";
    }

    private void CreateOrderFromUi()
    {
        _lblDraftError.Text = string.Empty;
        if (_draft.Rows.Count == 0)
        {
            _lblDraftError.Text = "Đơn hàng phải có ít nhất một sản phẩm.";
            return;
        }
        if (_buyer is null || _cboEmployee.SelectedValue is null)
        {
            _lblDraftError.Text = "Vui lòng chọn khách hàng và nhân viên.";
            return;
        }

        /* Giữ nguyên giây: CSDL so sánh NgayLap với NgayDangBan (có giây).
           Cắt giây sẽ khiến đơn lập trong cùng phút với lúc đăng bán bị chặn oan. */
        var ngayLap = _dtpOrder.Value.Date + DateTime.Now.TimeOfDay;
        var hanThanhToan = _dtpDue.Value.Date.AddHours(17);
        if (hanThanhToan < ngayLap)
        {
            _lblDraftError.Text = "Hạn thanh toán phải sau thời điểm lập đơn. Chọn ngày hạn muộn hơn.";
            _dtpDue.Focus();
            return;
        }

        try
        {
            var lines = Db.NewOrderLineTable();
            foreach (DataRow src in _draft.Rows)
            {
                var dst = lines.NewRow();
                dst["MaSP"] = src["MaSP"];
                dst["GiamGia"] = src["GiamGia"];
                lines.Rows.Add(dst);
            }

            using var cn = Db.Open();
            using var cmd = new SqlCommand("dbo.sp_TaoDonHang", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.AddWithValue("@MaKH", Convert.ToInt32(_buyer["MaKH"]));
            cmd.Parameters.AddWithValue("@MaNV", Convert.ToInt32(_cboEmployee.SelectedValue));
            cmd.Parameters.AddWithValue("@NgayLap", ngayLap);
            cmd.Parameters.AddWithValue("@HanThanhToan", hanThanhToan);
            cmd.Parameters.AddWithValue("@GhiChu", _txtNote.Text.Trim().Length == 0 ? DBNull.Value : _txtNote.Text.Trim());
            cmd.Parameters.Add(Db.Structured("@ChiTiet", "dbo.ChiTietDonHangType", lines));
            var output = new SqlParameter("@MaDH", SqlDbType.Int) { Direction = ParameterDirection.Output };
            cmd.Parameters.Add(output);
            cmd.ExecuteNonQuery();

            var maDh = Convert.ToInt32(output.Value);
            MessageBox.Show($"Đã tạo đơn #{maDh} và giữ {_draft.Rows.Count} sản phẩm.\nĐơn đang ở trạng thái Chờ thanh toán.",
                "Tạo đơn thành công", MessageBoxButtons.OK, MessageBoxIcon.Information);

            _draft.Rows.Clear();
            _txtNote.Clear();
            UpdateTotal();
            LoadProducts();
            _selected = null;
            _numPay.Value = 0;
            LoadOrders(maDh);
        }
        catch (Exception ex)
        {
            _lblDraftError.Text = Db.ErrorMessage(ex);
        }
    }

    private void RecordPayment()
    {
        if (_selected is null)
        {
            SetOrderMessage("Chọn một đơn hàng trước khi thu tiền.", true);
            return;
        }
        var soTien = Theme.MoneyValue(_numPay);
        if (soTien <= 0)
        {
            SetOrderMessage("Số tiền thu phải lớn hơn 0.", true);
            return;
        }
        if (!Theme.MoneyInRange(soTien, out var moneyError))
        {
            SetOrderMessage(moneyError!, true);
            return;
        }

        try
        {
            using var cn = Db.Open();
            using var cmd = new SqlCommand("dbo.sp_GhiNhanThanhToan", cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.AddWithValue("@MaDH", _selected.Value.MaDH);
            cmd.Parameters.AddWithValue("@SoTien", soTien);
            cmd.Parameters.AddWithValue("@PhuongThuc", Convert.ToString(_cboMethod.SelectedItem));
            cmd.Parameters.AddWithValue("@TrangThai", Convert.ToString(_cboPayStatus.SelectedItem));
            cmd.Parameters.AddWithValue("@MaGiaoDich", _txtTxn.Text.Trim().Length == 0 ? DBNull.Value : _txtTxn.Text.Trim());
            cmd.Parameters.AddWithValue("@GhiChu", _txtPayNote.Text.Trim().Length == 0 ? DBNull.Value : _txtPayNote.Text.Trim());
            var output = new SqlParameter("@MaTTDH", SqlDbType.Int) { Direction = ParameterDirection.Output };
            cmd.Parameters.Add(output);
            cmd.ExecuteNonQuery();

            var result = Convert.ToString(_cboPayStatus.SelectedItem);
            MessageBox.Show(result == "Thành công"
                    ? "Đã ghi nhận thanh toán. Nếu tổng tiền đã đủ, đơn chuyển sang Đang xử lý và sản phẩm chuyển Đã bán."
                    : "Đã ghi nhận giao dịch ở trạng thái " + result + ". Đơn hàng chưa thay đổi trạng thái.",
                "Ghi nhận thanh toán", MessageBoxButtons.OK, MessageBoxIcon.Information);
            _numPay.Value = 0;
            _txtTxn.Clear();
            _txtPayNote.Clear();
            LoadOrders(_selected.Value.MaDH);
        }
        catch (Exception ex)
        {
            SetOrderMessage(Db.ErrorMessage(ex), true);
        }
    }

    private void CompleteOrder()
    {
        if (_selected is null)
        {
            SetOrderMessage("Chọn một đơn hàng trước khi hoàn tất.", true);
            return;
        }
        try
        {
            ExecSpDb("dbo.sp_HoanTatDonHang", ("@MaDH", _selected.Value.MaDH));
            MessageBox.Show($"Đơn #{_selected.Value.MaDH} đã hoàn tất. Sản phẩm đủ điều kiện quyết toán cho người ký gửi.",
                "Hoàn tất đơn", MessageBoxButtons.OK, MessageBoxIcon.Information);
            LoadOrders(_selected.Value.MaDH);
        }
        catch (Exception ex)
        {
            SetOrderMessage(Db.ErrorMessage(ex), true);
        }
    }

    private void ResolvePendingPayments()
    {
        _lblOrderMessage.ForeColor = Theme.Muted;
        _lblOrderMessage.Text = string.Empty;

        if (_selected is null)
        {
            SetOrderMessage("Chọn một đơn hàng trước khi xử lý giao dịch treo.", true);
            Log.Write("GD treo: không có đơn được chọn");
            return;
        }

        var maDh = _selected.Value.MaDH;
        var dangTreo = Db.Long(
            "SELECT COUNT(*) FROM dbo.THANH_TOAN_DON_HANG WHERE MaDH = @MaDH AND TrangThai = N'Chờ xử lý'",
            Db.Param("@MaDH", maDh));

        Log.Write("GD treo: mở hộp thoại",
            new (string, object?)[] { ("MaDH", maDh), ("GiaoDichCho", dangTreo), ("TrangThaiDon", _selected.Value.TrangThai) });

        if (dangTreo == 0)
        {
            SetOrderMessage("Đơn này không có giao dịch nào đang chờ xử lý.", true);
            Log.Write("GD treo: bỏ qua vì không có giao dịch chờ", output: new (string, object?)[] { ("GiaoDichCho", 0L) });
            return;
        }

        try
        {
            using var dialog = new frmXuLyGiaoDichTreo(maDh);
            /* frmLapDonHang bị nhúng vào frmMain (TopLevel = false) nên KHÔNG được
               truyền nó làm owner — phải lấy cửa sổ cấp cao nhất. */
            var ownerWindow = Parent?.FindForm() ?? FindForm();
            var result = ownerWindow is null ? dialog.ShowDialog() : dialog.ShowDialog(ownerWindow);

            Log.Write("GD treo: đóng hộp thoại",
                output: new (string, object?)[] { ("DialogResult", result), ("DaThayDoi", dialog.Changed) });

            LoadOrders(maDh);
            LoadProducts();
        }
        catch (Exception ex)
        {
            SetOrderMessage("Không mở được hộp thoại giao dịch treo: " + Db.ErrorMessage(ex), true);
            Log.Write("GD treo: LỖI", new (string, object?)[] { ("MaDH", maDh) }, error: ex);
        }
    }

    private void CancelOrder()
    {
        if (_selected is null)
        {
            SetOrderMessage("Chọn một đơn hàng trước khi hủy.", true);
            return;
        }
        var reason = _txtCancelReason.Text.Trim();
        if (reason.Length == 0)
        {
            SetOrderMessage("Phải nhập lý do hủy đơn.", true);
            _txtCancelReason.Focus();
            return;
        }
        try
        {
            ExecSpDb("dbo.sp_HuyDonHang", ("@MaDH", _selected.Value.MaDH), ("@LyDo", reason));
            MessageBox.Show($"Đơn #{_selected.Value.MaDH} đã hủy. Sản phẩm được đưa trở lại trạng thái Đang bán.",
                "Hủy đơn", MessageBoxButtons.OK, MessageBoxIcon.Information);
            _txtCancelReason.Clear();
            LoadProducts();
            LoadOrders(_selected.Value.MaDH);
        }
        catch (Exception ex)
        {
            SetOrderMessage(Db.ErrorMessage(ex), true);
        }
    }

    private void SetOrderMessage(string message, bool error)
    {
        _lblOrderMessage.Text = message;
        _lblOrderMessage.ForeColor = error ? Theme.Danger : Theme.Muted;
    }

    private static void ExecSpDb(string name, params (string, object?)[] args)
    {
        using var cn = Db.Open();
        using var cmd = new SqlCommand(name, cn) { CommandType = CommandType.StoredProcedure };
        foreach (var (key, value) in args) cmd.Parameters.Add(Db.Param(key, value));
        if (name.EndsWith("sp_HoanTatDonHang", StringComparison.Ordinal)) cmd.CommandTimeout = 30;
        cmd.ExecuteNonQuery();
    }

    public void PrepareCapture()
    {
        var customers = Db.Query("SELECT TOP (1) MaKH, HoTen, SoDienThoai, Email, DiaChi FROM dbo.KHACH_HANG ORDER BY MaKH");
        if (customers.Rows.Count > 0) { _buyer = customers.Rows[0]; UpdateBuyerInfo(); }
        if (_cboEmployee.Items.Count > 0) _cboEmployee.SelectedIndex = 0;
        _txtNote.Text = "Khách chọn 2 món, hẹn nhận hàng trong ngày.";
        if (_gridProducts.Rows.Count > 0)
        {
            _numDiscount.Value = 50000;
            _gridProducts.CurrentCell = _gridProducts.Rows[0].Cells["TenSP"];
            AddSelectedProduct();
            if (_gridProducts.Rows.Count > 1)
            {
                _numDiscount.Value = 0;
                _gridProducts.CurrentCell = _gridProducts.Rows[1].Cells["TenSP"];
                AddSelectedProduct();
            }
        }

        // Chọn đơn đã thu một phần để minh họa bảng thanh toán.
        foreach (DataGridViewRow row in _gridOrders.Rows)
        {
            if (Convert.ToString(row.Cells["TrangThai"].Value) == "Chờ thanh toán" &&
                Convert.ToDecimal(row.Cells["DaThu"].Value) > 0)
            {
                _gridOrders.CurrentCell = row.Cells["MaDH"];
                row.Selected = true;
                break;
            }
        }
        ShowSelectedOrder();
    }
}
