using System;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using Microsoft.Data.SqlClient;

namespace QuanLyKyGui;

internal sealed class frmTiepNhanKyGui : Form
{
	private DataRow? _selectedCustomer;
	private readonly Label _customerName = new() { Dock = DockStyle.Fill, Font = Theme.H2, ForeColor = Theme.Ink, AutoEllipsis = true };
	private readonly Label _customerHint = new() { Dock = DockStyle.Fill, Font = Theme.Small, ForeColor = Theme.Muted };
	private readonly Button _findCustomer = Theme.PrimaryButton("Tìm khách hàng", 160);
	private readonly Button _addCustomer = Theme.GhostButton("+ Thêm khách mới", 174);
	private readonly TableLayoutPanel _customerSections = new();

	private readonly ComboBox _cboEmployee = Theme.Combo(200);

	private readonly DateTimePicker _dtpDate = Theme.DatePicker(150);



	private readonly TextBox _txtNote = new TextBox
	{
		Multiline = true,
		Height = 50,
		Width = 340,
		Font = Theme.Body,
		BorderStyle = BorderStyle.FixedSingle
	};

	private readonly Label _lblContact = new Label
	{
		AutoSize = false,
		Width = 368,
		Height = 36,
		Font = Theme.Small,
		ForeColor = Theme.Muted,
		AutoEllipsis = false
	};

	private readonly ComboBox _cboCategory = Theme.Combo(140);

	private readonly ComboBox _cboBrand = Theme.Combo(190);

	private readonly TextBox _txtName = Theme.TextBox(null, 200);

	private readonly TextBox _txtSize = Theme.TextBox(null, 80);

	private readonly TextBox _txtColor = Theme.TextBox(null, 80);

	private readonly TextBox _txtMaterial = Theme.TextBox(null, 90);

	private readonly TextBox _txtCondition = Theme.TextBox("Đã qua sử dụng, còn tốt 90%", 180);

	private readonly NumericUpDown _numProposed = Theme.Number(Theme.MoneyMax, 120);

	private readonly DataGridView _grid = new DataGridView();

	private readonly DataTable _draft;

	private readonly Label _lblCount = new Label
	{
		AutoSize = true,
		Font = Theme.Bold,
		ForeColor = Theme.Ink
	};

	private readonly Label _lblFormError = new Label
	{
		Dock = DockStyle.Fill,
		Font = Theme.Small,
		ForeColor = Theme.Danger
	};

	public frmTiepNhanKyGui()
	{
		Text = "Tiếp nhận ký gửi — Thiên Kim Consignment";
		base.ClientSize = new Size(1360, 830);
		MinimumSize = new Size(1180, 740);
		base.StartPosition = FormStartPosition.CenterParent;
		BackColor = Theme.Canvas;
		Font = Theme.Body;
		_draft = BuildDraftTable();
		BuildUi();
		LoadLookups();
		base.Shown += delegate
		{
			_findCustomer.Focus();
		};
	}

	private static DataTable BuildDraftTable()
	{
		DataTable dataTable = new DataTable();
		dataTable.Columns.Add("MaDM", typeof(int));
		dataTable.Columns.Add("MaTH", typeof(int));
		dataTable.Columns.Add("TenSP", typeof(string));
		dataTable.Columns.Add("TenDanhMuc", typeof(string));
		dataTable.Columns.Add("TenThuongHieu", typeof(string));
		dataTable.Columns.Add("KichThuoc", typeof(string));
		dataTable.Columns.Add("MauSac", typeof(string));
		dataTable.Columns.Add("ChatLieu", typeof(string));
		dataTable.Columns.Add("TinhTrang", typeof(string));
		dataTable.Columns.Add("GiaDeXuat", typeof(decimal));
		return dataTable;
	}

	private void BuildUi()
	{
		TableLayoutPanel tableLayoutPanel = new TableLayoutPanel
		{
			Dock = DockStyle.Fill,
			ColumnCount = 1,
			RowCount = 2,
			Padding = new Padding(20, 14, 20, 14),
			BackColor = Theme.Canvas
		};
		tableLayoutPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 72f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
		tableLayoutPanel.Controls.Add(BuildTitle(), 0, 0);
		TableLayoutPanel tableLayoutPanel2 = new TableLayoutPanel
		{
			Dock = DockStyle.Fill,
			ColumnCount = 2,
			RowCount = 1,
			Margin = new Padding(0)
		};
		tableLayoutPanel2.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 400f));
		tableLayoutPanel2.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
		tableLayoutPanel2.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
		tableLayoutPanel2.Controls.Add(BuildCustomerCard(), 0, 0);
		tableLayoutPanel2.Controls.Add(BuildProductCard(), 1, 0);
		tableLayoutPanel.Controls.Add(tableLayoutPanel2, 0, 1);
		base.Controls.Add(tableLayoutPanel);
		SyncDraftColumns();
	}

	private Control BuildTitle()
	{
		TableLayoutPanel tableLayoutPanel = new TableLayoutPanel
		{
			Dock = DockStyle.Fill,
			ColumnCount = 2,
			RowCount = 1,
			Margin = new Padding(0)
		};
		tableLayoutPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
		tableLayoutPanel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
		Panel panel = new Panel
		{
			Dock = DockStyle.Fill,
			BackColor = Color.Transparent
		};
		panel.Controls.Add(new Label
		{
			Text = "Tiếp nhận ký gửi",
			Font = Theme.H1,
			ForeColor = Theme.Ink,
			AutoSize = true,
			Location = new Point(0, 0)
		});
		panel.Controls.Add(new Label
		{
			Text = "Ghi nhận người gửi và đồ tiếp nhận. Sản phẩm được xét duyệt sau khi lưu phiếu.",
			Font = Theme.Small,
			ForeColor = Theme.Muted,
			AutoSize = true,
			Location = new Point(2, 40)
		});
		tableLayoutPanel.Controls.Add(panel, 0, 0);
		Button button = Theme.GhostButton("Đóng", 100);
		button.Click += delegate
		{
			Close();
		};
		Button button2 = Theme.PrimaryButton("Lưu phiếu tiếp nhận", 190);
		button2.Click += delegate
		{
			SaveSlip();
		};
		Panel control = Theme.Actions(button, button2);
		tableLayoutPanel.Controls.Add(control, 1, 0);
		return tableLayoutPanel;
	}

	private Control BuildCustomerCard()
	{
		var scroll = new Panel { Dock = DockStyle.Fill, AutoScroll = true, Margin = new Padding(0, 0, 14, 0) };
		_customerSections.Dock = DockStyle.Top;
		_customerSections.Height = 450;
		_customerSections.ColumnCount = 1;
		_customerSections.RowCount = 2;
		_customerSections.Margin = new Padding(0);
		_customerSections.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
		_customerSections.RowStyles.Add(new RowStyle(SizeType.Absolute, 190));
		_customerSections.RowStyles.Add(new RowStyle(SizeType.Absolute, 260));

		var customerCard = new Card("Người ký gửi") { Dock = DockStyle.Fill };
		var customer = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 4, Margin = new Padding(0) };
		customer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
		customer.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
		customer.RowStyles.Add(new RowStyle(SizeType.Absolute, 30));
		customer.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
		customer.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
		customer.Controls.Add(_customerName, 0, 0);
		customer.Controls.Add(_customerHint, 0, 1);
		_lblContact.Dock = DockStyle.Fill;
		_lblContact.Margin = new Padding(0, 0, 0, 8);
		_lblContact.ForeColor = Theme.Ink;
		_lblContact.Font = Theme.Body;
		_lblContact.AutoEllipsis = true;
		customer.Controls.Add(_lblContact, 0, 2);
		var actions = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false, Margin = new Padding(0) };
		_findCustomer.Margin = new Padding(0, 0, 8, 0);
		_addCustomer.Margin = new Padding(0);
		_findCustomer.Click += (_, _) => SearchCustomer();
		_addCustomer.Click += (_, _) => AddCustomer();
		actions.Controls.Add(_findCustomer);
		actions.Controls.Add(_addCustomer);
		customer.Controls.Add(actions, 0, 3);
		customerCard.Body.Controls.Add(customer);
		_customerSections.Controls.Add(customerCard, 0, 0);

		var receiptCard = new Card("Thông tin tiếp nhận") { Dock = DockStyle.Fill, Margin = new Padding(0) };
		var receipt = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3, Margin = new Padding(0) };
		receipt.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
		receipt.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
		receipt.RowStyles.Add(new RowStyle(SizeType.Absolute, 58));
		receipt.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
		receipt.Controls.Add(IntakeField("Nhân viên tiếp nhận", _cboEmployee), 0, 0);
		receipt.Controls.Add(IntakeField("Ngày ký gửi", _dtpDate), 0, 1);
		receipt.Controls.Add(IntakeField("Ghi chú phiếu ký gửi", _txtNote), 0, 2);
		receiptCard.Body.Controls.Add(receipt);
		_customerSections.Controls.Add(receiptCard, 0, 1);
		scroll.Controls.Add(_customerSections);
		UpdateCustomerInfo();
		return scroll;
	}
	private static Control IntakeField(string title, Control input)
	{
		var field = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, Margin = new Padding(0, 0, 0, 6) };
		field.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
		field.RowStyles.Add(new RowStyle(SizeType.Absolute, 20));
		field.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
		field.Controls.Add(new Label { Text = title, Dock = DockStyle.Fill, Font = Theme.Small, ForeColor = Theme.Muted }, 0, 0);
		input.Dock = DockStyle.Fill;
		input.Margin = new Padding(0);
		field.Controls.Add(input, 0, 1);
		return field;
	}
	private Control BuildProductCard()
	{
		Card card = new Card("Sản phẩm ký gửi trong phiếu");
		card.Dock = DockStyle.Fill;
		card.Margin = new Padding(0);
		TableLayoutPanel tableLayoutPanel = new TableLayoutPanel
		{
			Dock = DockStyle.Fill,
			ColumnCount = 1,
			RowCount = 4,
			Margin = new Padding(0)
		};
		tableLayoutPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 186f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 38f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 50f));
		FlowLayoutPanel flowLayoutPanel = Fields.Flow(860, 186);
		flowLayoutPanel.Dock = DockStyle.Fill;
		flowLayoutPanel.Controls.Add(Fields.Field("Danh mục", _cboCategory));
		flowLayoutPanel.Controls.Add(Fields.Field("Thương hiệu", _cboBrand));
		flowLayoutPanel.Controls.Add(Fields.Field("Tên sản phẩm", _txtName));
		flowLayoutPanel.Controls.Add(Fields.Field("Kích thước", _txtSize));
		flowLayoutPanel.Controls.Add(Fields.Field("Màu sắc", _txtColor));
		flowLayoutPanel.Controls.Add(Fields.Field("Chất liệu", _txtMaterial));
		flowLayoutPanel.Controls.Add(Fields.Field("Tình trạng", _txtCondition));
		flowLayoutPanel.Controls.Add(Fields.Field("Giá đề xuất", _numProposed));
		tableLayoutPanel.Controls.Add(flowLayoutPanel, 0, 0);
		Theme.StyleGrid(_grid);
		_grid.Dock = DockStyle.Fill;
		_grid.Margin = new Padding(0, 4, 0, 8);
		tableLayoutPanel.Controls.Add(_grid, 0, 1);
		TableLayoutPanel tableLayoutPanel2 = new TableLayoutPanel
		{
			Dock = DockStyle.Fill,
			ColumnCount = 4,
			RowCount = 1,
			Margin = new Padding(0)
		};
		tableLayoutPanel2.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
		tableLayoutPanel2.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
		tableLayoutPanel2.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
		tableLayoutPanel2.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
		_lblCount.AutoSize = false;
		_lblCount.Dock = DockStyle.Fill;
		_lblCount.TextAlign = ContentAlignment.MiddleLeft;
		tableLayoutPanel2.Controls.Add(_lblCount, 0, 0);
		tableLayoutPanel.Controls.Add(_lblFormError, 0, 2);
		Button button = Theme.GoldButton("+  Thêm sản phẩm");
		button.Click += delegate
		{
			TryAddFromInputs();
		};
		tableLayoutPanel2.Controls.Add(button, 1, 0);
		Button button2 = Theme.GhostButton("Xóa dòng", 100);
		button2.Click += delegate
		{
			RemoveSelected();
		};
		tableLayoutPanel2.Controls.Add(button2, 2, 0);
		Button button3 = Theme.PrimaryButton("Lưu phiếu tiếp nhận", 180);
		button3.Click += delegate
		{
			SaveSlip();
		};
		tableLayoutPanel2.Controls.Add(button3, 3, 0);
		tableLayoutPanel.Controls.Add(tableLayoutPanel2, 0, 3);
		card.Body.Controls.Add(tableLayoutPanel);
		return card;
	}

	private void LoadCustomers(int selectId)
	{
		var customers = Db.Query("SELECT MaKH, HoTen, SoDienThoai, Email, DiaChi FROM dbo.KHACH_HANG WHERE MaKH = @Id",
			Db.Param("@Id", selectId));
		if (customers.Rows.Count == 0)
			throw new InvalidOperationException("Hồ sơ khách hàng không còn tồn tại. Vui lòng chọn lại.");
		_selectedCustomer = customers.Rows[0];
		UpdateCustomerInfo();
	}
	private void LoadLookups()
	{
		try
		{

			DataTable dataTable = Db.Query("SELECT MaNV, HoTen, ChucVu FROM dbo.NHAN_VIEN WHERE TrangThai = N'Đang làm việc' ORDER BY HoTen");
			DataTable dataTable2 = dataTable.Copy();
			dataTable2.Columns.Add("HienThi", typeof(string));
			foreach (DataRow row in dataTable2.Rows)
			{
				row["HienThi"] = $"{row["HoTen"]} ({row["ChucVu"]})";
			}
			_cboEmployee.DataSource = dataTable2;
			_cboEmployee.DisplayMember = "HienThi";
			_cboEmployee.ValueMember = "MaNV";
			DemoSession.SelectManager(_cboEmployee);
			_cboCategory.DataSource = Db.Query("SELECT MaDM, TenDanhMuc FROM dbo.DANH_MUC ORDER BY TenDanhMuc");
			_cboCategory.DisplayMember = "TenDanhMuc";
			_cboCategory.ValueMember = "MaDM";
			DataTable dataTable3 = Db.Query("SELECT MaTH, TenThuongHieu FROM dbo.THUONG_HIEU ORDER BY TenThuongHieu");
			DataTable dataTable4 = dataTable3.Copy();
			DataRow dataRow2 = dataTable4.NewRow();
			dataRow2["MaTH"] = DBNull.Value;
			dataRow2["TenThuongHieu"] = "(Không có thương hiệu)";
			dataTable4.Rows.InsertAt(dataRow2, 0);
			_cboBrand.DataSource = dataTable4;
			_cboBrand.DisplayMember = "TenThuongHieu";
			_cboBrand.ValueMember = "MaTH";
			_dtpDate.Value = DateTime.Now;
			UpdateCustomerInfo();
		}
		catch (Exception ex)
		{
			MessageBox.Show("Không tải được danh mục: " + Db.ErrorMessage(ex), "Lỗi", MessageBoxButtons.OK, MessageBoxIcon.Hand);
		}
	}

	private void UpdateCustomerInfo()
	{
		var selected = _selectedCustomer is not null;
		_customerName.Text = selected ? Convert.ToString(_selectedCustomer!["HoTen"]) : "Chưa chọn khách hàng";
		_customerHint.Text = selected ? $"Mã khách hàng: KH{_selectedCustomer!["MaKH"]}" : "Tìm khách có sẵn hoặc thêm hồ sơ mới.";
		_lblContact.Visible = selected;
		_findCustomer.Text = selected ? "Đổi khách" : "Tìm khách hàng";
		_addCustomer.Visible = !selected;
		_customerSections.RowStyles[0].Height = selected ? 290 : 190;
		_customerSections.Height = selected ? 550 : 450;
		if (_selectedCustomer is DataRow customer)
		{
			string Value(string column) => string.IsNullOrWhiteSpace(Convert.ToString(customer[column]))
				? "Chưa cập nhật" : Convert.ToString(customer[column])!;
			_lblContact.Text = $"Điện thoại: {Value("SoDienThoai")}\r\nEmail: {Value("Email")}\r\nĐịa chỉ: {Value("DiaChi")}";
		}
		else _lblContact.Text = "";
	}
	private void AddCustomer()
	{
		using var dialog = new frmKhachHangMoi();
		if (dialog.ShowDialog(this) != DialogResult.OK) return;
		try { LoadCustomers(dialog.NewCustomerId); }
		catch (Exception ex)
		{
			MessageBox.Show(this, "Đã tạo khách hàng nhưng chưa tải được hồ sơ: " + Db.ErrorMessage(ex),
				"Thông tin khách hàng", MessageBoxButtons.OK, MessageBoxIcon.Warning);
		}
	}
	private void SearchCustomer()
	{
		int? currentId = _selectedCustomer is null ? null : Convert.ToInt32(_selectedCustomer["MaKH"]);
		using var dialog = new frmChonKhachHang(currentId);
		if (dialog.ShowDialog(this) != DialogResult.OK || dialog.SelectedCustomer is null) return;
		_selectedCustomer = dialog.SelectedCustomer;
		UpdateCustomerInfo();
	}
	private void SyncDraftColumns()
	{
		Theme.StyleGrid(_grid);
		_grid.AutoGenerateColumns = false;
		_grid.Columns.Clear();
		_grid.Columns.Add(Theme.TextColumn("TenSP", "Tên sản phẩm", 190));
		_grid.Columns.Add(Theme.TextColumn("TenDanhMuc", "Danh mục", 75));
		_grid.Columns.Add(Theme.TextColumn("TenThuongHieu", "Thương hiệu", 80));
		_grid.Columns.Add(Theme.TextColumn("KichThuoc", "Kích thước", 66));
		_grid.Columns.Add(Theme.TextColumn("MauSac", "Màu sắc", 50));
		_grid.Columns.Add(Theme.TextColumn("TinhTrang", "Tình trạng", 110));
		_grid.Columns.Add(Theme.TextColumn("GiaDeXuat", "Giá đề xuất", 80, money: true));
		_grid.DataSource = _draft;
		_lblCount.Text = "0 sản phẩm trong phiếu";
	}

	private bool TryAddFromInputs()
	{
		_lblFormError.Text = string.Empty;
		string text = _txtName.Text.Trim();
		string text2 = _txtCondition.Text.Trim();
		if (text.Length == 0)
		{
			_lblFormError.Text = "Tên sản phẩm không được để trống.";
			_txtName.Focus();
			return false;
		}
		if (text2.Length == 0)
		{
			_lblFormError.Text = "Tình trạng sản phẩm không được để trống.";
			_txtCondition.Focus();
			return false;
		}
		if (!(_cboCategory.SelectedValue is int maDm) || 1 == 0)
		{
			_lblFormError.Text = "Vui lòng chọn danh mục sản phẩm.";
			_cboCategory.Focus();
			return false;
		}
		var proposed = Theme.MoneyValue(_numProposed);
		if (!Theme.PriceInRange(proposed, out var priceError))
		{
			_lblFormError.Text = priceError;
			_numProposed.Focus();
			return false;
		}
		string text4 = _cboCategory.Text;
		object selectedValue = _cboBrand.SelectedValue;
		AddProductRow(text, maDm, text4, (selectedValue == null || selectedValue is DBNull) ? ((int?)null) : new int?(Convert.ToInt32(_cboBrand.SelectedValue)), _cboBrand.Text, _txtSize.Text.Trim(), _txtColor.Text.Trim(), _txtMaterial.Text.Trim(), text2, proposed);
		_txtName.Clear();
		_txtSize.Clear();
		_txtColor.Clear();
		_numProposed.Value = 0m;
		_txtName.Focus();
		return true;
	}

	private void AddProductRow(string name, int maDm, string category, int? maTh, string brand, string size, string color, string material, string condition, decimal proposed)
	{
		DataRow dataRow = _draft.NewRow();
		dataRow["MaDM"] = maDm;
		dataRow["MaTH"] = ((!maTh.HasValue) ? DBNull.Value : ((object)maTh.Value));
		dataRow["TenSP"] = name;
		dataRow["TenDanhMuc"] = category;
		dataRow["TenThuongHieu"] = brand;
		dataRow["KichThuoc"] = size;
		dataRow["MauSac"] = color;
		dataRow["ChatLieu"] = material;
		dataRow["TinhTrang"] = condition;
		dataRow["GiaDeXuat"] = proposed;
		_draft.Rows.Add(dataRow);
		_lblCount.Text = $"{_draft.Rows.Count} sản phẩm trong phiếu";
	}

	private void RemoveSelected()
	{
		if (_grid.CurrentRow?.DataBoundItem is DataRowView dataRowView)
		{
			_draft.Rows.Remove(dataRowView.Row);
			_lblCount.Text = $"{_draft.Rows.Count} sản phẩm trong phiếu";
		}
	}

	private void SaveSlip()
	{
		_lblFormError.Text = string.Empty;
		if (_selectedCustomer?["MaKH"] is int num)
		{
			object selectedValue = _cboEmployee.SelectedValue;
			int num2 = default(int);
			int num3;
			if (selectedValue is int)
			{
				num2 = (int)selectedValue;
				num3 = 1;
			}
			else
			{
				num3 = 0;
			}
			if (num3 != 0)
			{
				if (!string.IsNullOrWhiteSpace(_txtName.Text) && !TryAddFromInputs())
				{
					return;
				}
				if (_draft.Rows.Count == 0)
				{
					_lblFormError.Text = "Phiếu ký gửi phải có ít nhất một sản phẩm. Hãy nhập tên sản phẩm.";
					_txtName.Focus();
					return;
				}
				try
				{
					DataTable dataTable = Db.NewProductTable();
					foreach (DataRow row in _draft.Rows)
					{
						DataRow dataRow2 = dataTable.NewRow();
						dataRow2["MaDM"] = row["MaDM"];
						dataRow2["MaTH"] = row["MaTH"];
						dataRow2["TenSP"] = row["TenSP"];
						dataRow2["MoTa"] = row["TenSP"];
						dataRow2["KichThuoc"] = row["KichThuoc"];
						dataRow2["MauSac"] = row["MauSac"];
						dataRow2["ChatLieu"] = row["ChatLieu"];
						dataRow2["TinhTrang"] = row["TinhTrang"];
						dataRow2["GiaDeXuat"] = row["GiaDeXuat"];
						dataRow2["GiaDangBan"] = DBNull.Value;
						dataRow2["TrangThaiTiepNhan"] = "Chờ xử lý";
						dataTable.Rows.Add(dataRow2);
					}
					using SqlConnection connection = Db.Open();
					using SqlCommand sqlCommand = new SqlCommand("dbo.sp_TiepNhanPhieuKyGui", connection)
					{
						CommandType = CommandType.StoredProcedure
					};
					sqlCommand.Parameters.AddWithValue("@MaKH", num);
					sqlCommand.Parameters.AddWithValue("@MaNV", num2);
					/* Giữ nguyên giây để khớp độ chính xác DATETIME2(0) của CSDL. */
					sqlCommand.Parameters.AddWithValue("@NgayKyGui", _dtpDate.Value.Date + DateTime.Now.TimeOfDay);
					sqlCommand.Parameters.AddWithValue("@GhiChu", (_txtNote.Text.Trim().Length == 0) ? ((IConvertible)DBNull.Value) : ((IConvertible)_txtNote.Text.Trim()));
					sqlCommand.Parameters.Add(Db.Structured("@SanPham", "dbo.SanPhamKyGuiType", dataTable));
					SqlParameter sqlParameter = new SqlParameter("@MaPKG", SqlDbType.Int)
					{
						Direction = ParameterDirection.Output
					};
					sqlCommand.Parameters.Add(sqlParameter);
					sqlCommand.ExecuteNonQuery();
					int value = Convert.ToInt32(sqlParameter.Value);
					MessageBox.Show($"Đã lưu phiếu tiếp nhận #{value} với {_draft.Rows.Count} sản phẩm.\nToàn bộ sản phẩm đang Chờ xử lý. Mở Xét duyệt ký gửi để duyệt từng món trước khi đăng bán.", "Lưu thành công", MessageBoxButtons.OK, MessageBoxIcon.Asterisk);
					_draft.Rows.Clear();
					_lblCount.Text = "0 sản phẩm trong phiếu";
					_txtNote.Clear();
					_txtName.Focus();
					return;
				}
				catch (Exception ex)
				{
					MessageBox.Show(this, Db.ErrorMessage(ex), "Không lưu được phiếu ký gửi", MessageBoxButtons.OK, MessageBoxIcon.Hand);
					return;
				}
			}
		}
		_lblFormError.Text = "Vui lòng chọn khách hàng và nhân viên tiếp nhận.";
	}

	public void PrepareCapture()
	{
		var sample = Db.Query("SELECT TOP (1) MaKH FROM dbo.KHACH_HANG ORDER BY MaKH");
		if (sample.Rows.Count > 0) LoadCustomers(Convert.ToInt32(sample.Rows[0]["MaKH"]));
		if (_cboEmployee.Items.Count > 0)
		{
			_cboEmployee.SelectedIndex = 0;
		}
		_txtNote.Text = "Khách mang 2 món đến ký gửi, đã kiểm tra cùng khách và chụp ảnh sản phẩm.";
		AddProductRow("Đầm lụa Zara dáng suông", 1, "Quần áo", 3, "Zara", "M", "Đen", "Lụa pha", "Đã qua sử dụng, còn tốt 90%", 650000m);
		AddProductRow("Túi xách da Mango", 4, "Túi xách", 10, "Mango", "One size", "Nâu", "Da PU", "Còn mới 98%, chưa dùng", 480000m);
		AddProductRow("Mũ beret nỉ", 3, "Mũ nón", null, "(Không có thương hiệu)", "Free size", "Đen", "Nỉ", "Đã qua sử dụng, còn tốt 80%", 180000m);
		_lblFormError.Text = string.Empty;
	}
}
