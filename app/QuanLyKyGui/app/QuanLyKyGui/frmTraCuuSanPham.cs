using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Windows.Forms;
using Microsoft.Data.SqlClient;

namespace QuanLyKyGui;

internal sealed class frmTraCuuSanPham : Form
{
	private readonly TextBox _txtKeyword = Theme.TextBox(null, 200);

	private readonly ComboBox _cboCategory = Theme.Combo(150);

	private readonly ComboBox _cboBrand = Theme.Combo(155);

	private readonly TextBox _txtSize = Theme.TextBox(null, 90);

	private readonly ComboBox _cboStatus = Theme.Combo(145);

	private readonly ComboBox _cboCustomer = Theme.Combo(195);

	private readonly NumericUpDown _numFrom = Theme.Number(Theme.PriceMax, 110);

	private readonly NumericUpDown _numTo = Theme.Number(Theme.PriceMax, 110);

	private readonly DataGridView _grid = new DataGridView();

	private readonly Label _lblSummary = new Label
	{
		AutoSize = true,
		Font = Theme.Bold,
		ForeColor = Theme.Ink
	};

	private readonly Label _lblDetail = new Label
	{
		Dock = DockStyle.Fill,
		Font = Theme.Body,
		ForeColor = Theme.Ink
	};

	private DataTable _current = new DataTable();

	public frmTraCuuSanPham()
	{
		Text = "Tra cứu sản phẩm — Thiên Kim Consignment";
		base.ClientSize = new Size(1360, 830);
		MinimumSize = new Size(1180, 740);
		base.StartPosition = FormStartPosition.CenterParent;
		BackColor = Theme.Canvas;
		Font = Theme.Body;
		BuildUi();
		LoadLookups();
		base.Shown += delegate
		{
			Search();
		};
	}

	private void BuildUi()
	{
		TableLayoutPanel tableLayoutPanel = new TableLayoutPanel
		{
			Dock = DockStyle.Fill,
			ColumnCount = 1,
			RowCount = 4,
			Padding = new Padding(20, 14, 20, 14),
			BackColor = Theme.Canvas
		};
		tableLayoutPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 72f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 162f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 128f));
		tableLayoutPanel.Controls.Add(BuildTitle(), 0, 0);
		tableLayoutPanel.Controls.Add(BuildFilterCard(), 0, 1);
		tableLayoutPanel.Controls.Add(BuildResultCard(), 0, 2);
		tableLayoutPanel.Controls.Add(BuildDetailCard(), 0, 3);
		base.Controls.Add(tableLayoutPanel);
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
			Text = "Tra cứu sản phẩm",
			Font = Theme.H1,
			ForeColor = Theme.Ink,
			AutoSize = true,
			Location = new Point(0, 0)
		});
		panel.Controls.Add(new Label
		{
			Text = "Tìm theo tên, thương hiệu, người ký gửi, danh mục, kích thước, trạng thái và khoảng giá.",
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
		Button button2 = Theme.GhostButton("Trả hàng", 120);
		button2.ForeColor = Theme.Danger;
		button2.Click += delegate
		{
			ReturnSelectedProduct();
		};
		Button button3 = Theme.PrimaryButton("Đăng bán", 130);
		button3.Click += delegate
		{
			ListSelectedProduct();
		};
		Button button4 = Theme.GoldButton("Xuất Excel", 150);
		button4.Click += delegate
		{
			Export();
		};
		Panel control = Theme.Actions(button, button2, button3, button4);
		tableLayoutPanel.Controls.Add(control, 1, 0);
		return tableLayoutPanel;
	}

	private Control BuildFilterCard()
	{
		Card card = new Card("Bộ lọc tra cứu");
		card.Dock = DockStyle.Fill;
		card.Margin = new Padding(0, 0, 0, 12);
		card.Padding = new Padding(16, 44, 16, 10);
		TableLayoutPanel tableLayoutPanel = new TableLayoutPanel
		{
			Dock = DockStyle.Fill,
			ColumnCount = 1,
			RowCount = 2,
			Margin = new Padding(0)
		};
		tableLayoutPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 60f));
		tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 36f));
		FlowLayoutPanel flowLayoutPanel = Fields.Flow(1290, 60);
		flowLayoutPanel.Dock = DockStyle.Fill;
		flowLayoutPanel.Controls.Add(Fields.Field("Từ khóa", _txtKeyword));
		flowLayoutPanel.Controls.Add(Fields.Field("Danh mục", _cboCategory));
		flowLayoutPanel.Controls.Add(Fields.Field("Thương hiệu", _cboBrand));
		flowLayoutPanel.Controls.Add(Fields.Field("Kích thước", _txtSize));
		flowLayoutPanel.Controls.Add(Fields.Field("Trạng thái bán", _cboStatus));
		flowLayoutPanel.Controls.Add(Fields.Field("Người ký gửi", _cboCustomer));
		flowLayoutPanel.Controls.Add(Fields.Field("Giá từ", _numFrom));
		flowLayoutPanel.Controls.Add(Fields.Field("Giá đến", _numTo));
		tableLayoutPanel.Controls.Add(flowLayoutPanel, 0, 0);
		FlowLayoutPanel flowLayoutPanel2 = new FlowLayoutPanel
		{
			Dock = DockStyle.Fill,
			WrapContents = false,
			Margin = new Padding(0)
		};
		Button button = Theme.PrimaryButton("Tìm kiếm", 140);
		button.Click += delegate
		{
			Search();
		};
		flowLayoutPanel2.Controls.Add(button);
		Button button2 = Theme.GhostButton("Xóa bộ lọc", 130);
		button2.Click += delegate
		{
			ClearFilters();
		};
		flowLayoutPanel2.Controls.Add(button2);
		_lblSummary.Margin = new Padding(12, 8, 0, 0);
		flowLayoutPanel2.Controls.Add(_lblSummary);
		tableLayoutPanel.Controls.Add(flowLayoutPanel2, 0, 1);
		card.Body.Controls.Add(tableLayoutPanel);
		return card;
	}

	private Control BuildResultCard()
	{
		Card card = new Card("Kết quả tra cứu");
		card.Dock = DockStyle.Fill;
		card.Margin = new Padding(0, 0, 0, 12);
		Theme.StyleGrid(_grid);
		_grid.Dock = DockStyle.Fill;
		_grid.SelectionChanged += delegate
		{
			ShowDetail();
		};
		_grid.CellDoubleClick += delegate(object? _, DataGridViewCellEventArgs e)
		{
			if (e.RowIndex >= 0)
			{
				ShowDetail();
			}
		};
		card.Body.Controls.Add(_grid);
		return card;
	}

	private Control BuildDetailCard()
	{
		Card card = new Card("Chi tiết sản phẩm đang chọn", 40);
		card.Dock = DockStyle.Fill;
		card.Margin = new Padding(0);
		card.Padding = new Padding(16, 36, 16, 6);
		_lblDetail.Text = "Chọn một dòng trong kết quả để xem chi tiết.";
		_lblDetail.ForeColor = Theme.Muted;
		card.Body.Controls.Add(_lblDetail);
		return card;
	}

	private void LoadLookups()
	{
		try
		{
			DataTable dataTable = Db.Query("SELECT MaDM, TenDanhMuc FROM dbo.DANH_MUC ORDER BY TenDanhMuc");
			DataTable dataTable2 = dataTable.Copy();
			DataRow dataRow = dataTable2.NewRow();
			dataRow["MaDM"] = DBNull.Value;
			dataRow["TenDanhMuc"] = "(Tất cả danh mục)";
			dataTable2.Rows.InsertAt(dataRow, 0);
			_cboCategory.DataSource = dataTable2;
			_cboCategory.DisplayMember = "TenDanhMuc";
			_cboCategory.ValueMember = "MaDM";
			DataTable dataTable3 = Db.Query("SELECT MaTH, TenThuongHieu FROM dbo.THUONG_HIEU ORDER BY TenThuongHieu");
			DataTable dataTable4 = dataTable3.Copy();
			DataRow dataRow2 = dataTable4.NewRow();
			dataRow2["MaTH"] = DBNull.Value;
			dataRow2["TenThuongHieu"] = "(Tất cả thương hiệu)";
			dataTable4.Rows.InsertAt(dataRow2, 0);
			_cboBrand.DataSource = dataTable4;
			_cboBrand.DisplayMember = "TenThuongHieu";
			_cboBrand.ValueMember = "MaTH";
			DataTable dataTable5 = Db.Query("SELECT MaKH, HoTen FROM dbo.KHACH_HANG ORDER BY HoTen");
			DataTable dataTable6 = dataTable5.Copy();
			DataRow dataRow3 = dataTable6.NewRow();
			dataRow3["MaKH"] = DBNull.Value;
			dataRow3["HoTen"] = "(Tất cả người ký gửi)";
			dataTable6.Rows.InsertAt(dataRow3, 0);
			_cboCustomer.DataSource = dataTable6;
			_cboCustomer.DisplayMember = "HoTen";
			_cboCustomer.ValueMember = "MaKH";
			_cboStatus.Items.AddRange("(Tất cả trạng thái)", "Chưa đăng bán", "Đang bán", "Đang giữ", "Đã bán", "Đã trả lại");
			_cboStatus.SelectedIndex = 0;
		}
		catch (Exception ex)
		{
			MessageBox.Show("Không tải được bộ lọc: " + Db.ErrorMessage(ex), "Lỗi", MessageBoxButtons.OK, MessageBoxIcon.Hand);
		}
	}

	private void Search()
	{
		try
		{
			string text = _txtKeyword.Text.Trim();
			string text2 = _txtSize.Text.Trim();
			string text3 = ((_cboStatus.SelectedIndex <= 0) ? null : Convert.ToString(_cboStatus.SelectedItem));
			int? num = NullableInt(_cboCategory.SelectedValue);
			int? num2 = NullableInt(_cboBrand.SelectedValue);
			int? num3 = NullableInt(_cboCustomer.SelectedValue);
			var giaTu = Theme.MoneyValue(_numFrom);
			var giaDen = Theme.MoneyValue(_numTo);
			decimal? num4 = ((giaTu > 0m) ? new decimal?(giaTu) : ((decimal?)null));
			decimal? num5 = ((giaDen > 0m) ? new decimal?(giaDen) : ((decimal?)null));
			SqlParameter[] ps = new SqlParameter[8]
			{
				new SqlParameter("@TuKhoa", SqlDbType.NVarChar, 200)
				{
					Value = (((object)text) ?? ((object)DBNull.Value))
				},
				new SqlParameter("@MaDM", SqlDbType.Int)
				{
					Value = (((object)num) ?? DBNull.Value)
				},
				new SqlParameter("@MaTH", SqlDbType.Int)
				{
					Value = (((object)num2) ?? DBNull.Value)
				},
				new SqlParameter("@KichThuoc", SqlDbType.NVarChar, 50)
				{
					Value = (string.IsNullOrEmpty(text2) ? ((IConvertible)DBNull.Value) : ((IConvertible)text2))
				},
				new SqlParameter("@TrangThaiBan", SqlDbType.NVarChar, 20)
				{
					Value = (((object)text3) ?? ((object)DBNull.Value))
				},
				new SqlParameter("@MaKH", SqlDbType.Int)
				{
					Value = (((object)num3) ?? DBNull.Value)
				},
				new SqlParameter("@GiaTu", SqlDbType.Decimal)
				{
					Precision = 12,
					Scale = 0,
					Value = (((object)num4) ?? DBNull.Value)
				},
				new SqlParameter("@GiaDen", SqlDbType.Decimal)
				{
					Precision = 12,
					Scale = 0,
					Value = (((object)num5) ?? DBNull.Value)
				}
			};
			DataTable dataTable = (_current = Db.Query("EXEC dbo.sp_TraCuuSanPham @TuKhoa, @MaDM, @MaTH, @KichThuoc, @TrangThaiBan, @MaKH, @GiaTu, @GiaDen", ps));
			dataTable.Columns["MaSP"].Caption = "Mã SP";
			dataTable.Columns["TenSP"].Caption = "Tên sản phẩm";
			dataTable.Columns["TenDanhMuc"].Caption = "Danh mục";
			dataTable.Columns["TenThuongHieu"].Caption = "Thương hiệu";
			dataTable.Columns["KichThuoc"].Caption = "Kích thước";
			dataTable.Columns["MauSac"].Caption = "Màu sắc";
			dataTable.Columns["ChatLieu"].Caption = "Chất liệu";
			dataTable.Columns["TinhTrang"].Caption = "Tình trạng";
			dataTable.Columns["GiaDeXuat"].Caption = "Giá khách đề xuất";
			dataTable.Columns["GiaDangBan"].Caption = "Giá đăng bán";
			dataTable.Columns["TrangThaiTiepNhan"].Caption = "Duyệt";
			dataTable.Columns["TrangThaiBan"].Caption = "Trạng thái bán";
			dataTable.Columns["NgayDangBan"].Caption = "Ngày đăng bán";
			dataTable.Columns["MaPKG"].Caption = "Mã phiếu";
			dataTable.Columns["NgayKyGui"].Caption = "Ngày ký gửi";
			dataTable.Columns["TrangThaiPhieu"].Caption = "Trạng thái phiếu";
			dataTable.Columns["MaKH"].Caption = "Mã KH";
			dataTable.Columns["TenNguoiKyGui"].Caption = "Người ký gửi";
			dataTable.Columns["DienThoaiNguoiKyGui"].Caption = "SĐT";
			dataTable.Columns["TenNhanVienTiepNhan"].Caption = "Nhân viên tiếp nhận";
			_grid.DataSource = dataTable;
			Dictionary<string, string> dictionary = new Dictionary<string, string>
			{
				["TenSP"] = "Sản phẩm",
				["TenDanhMuc"] = "Danh mục",
				["TenThuongHieu"] = "Thương hiệu",
				["KichThuoc"] = "Size",
				["MauSac"] = "Màu",
				["TinhTrang"] = "Tình trạng",
				["TrangThaiTiepNhan"] = "Kết quả duyệt",
				["GiaDeXuat"] = "Giá khách đề xuất",
				["GiaDangBan"] = "Giá đăng bán",
				["TrangThaiBan"] = "Trạng thái",
				["NgayDangBan"] = "Ngày đăng",
				["TenNguoiKyGui"] = "Người ký gửi",
				["DienThoaiNguoiKyGui"] = "SĐT"
			};
			foreach (KeyValuePair<string, string> item in dictionary)
			{
				if (_grid.Columns.Contains(item.Key))
				{
					_grid.Columns[item.Key].HeaderText = item.Value;
				}
			}
			string[] array = new string[8] { "MaSP", "MaKH", "MaPKG", "ChatLieu", "NgayKyGui", "TrangThaiPhieu", "TenNhanVienTiepNhan", "DienThoaiNguoiKyGui" };
			foreach (string columnName in array)
			{
				if (_grid.Columns.Contains(columnName))
				{
					_grid.Columns[columnName].Visible = false;
				}
			}
			_grid.Columns["TenSP"].FillWeight = 180f;
			_grid.Columns["TenDanhMuc"].FillWeight = 80f;
			_grid.Columns["TenThuongHieu"].FillWeight = 95f;
			_grid.Columns["KichThuoc"].FillWeight = 55f;
			_grid.Columns["MauSac"].FillWeight = 55f;
			_grid.Columns["TinhTrang"].FillWeight = 120f;
			_grid.Columns["GiaDeXuat"]!.Visible = true;
			_grid.Columns["GiaDeXuat"]!.DisplayIndex = _grid.Columns["GiaDangBan"]!.DisplayIndex - 1;
			_grid.Columns["GiaDeXuat"]!.FillWeight = 100f;
			_grid.Columns["GiaDeXuat"]!.MinimumWidth = 110;
			_grid.Columns["GiaDangBan"].FillWeight = 100f;
			_grid.Columns["GiaDangBan"]!.MinimumWidth = 110;
			_grid.Columns["TrangThaiTiepNhan"]!.FillWeight = 125f;
			_grid.Columns["TrangThaiBan"].FillWeight = 120f;
			_grid.Columns["NgayDangBan"].FillWeight = 85f;
			_grid.Columns["TenNguoiKyGui"].FillWeight = 115f;
			Theme.MoneyColumn(_grid.Columns["GiaDeXuat"]);
			Theme.MoneyColumn(_grid.Columns["GiaDangBan"]);
			_grid.Columns["NgayDangBan"].DefaultCellStyle.Format = "dd/MM/yyyy";
			_lblSummary.Text = $"Tìm thấy {dataTable.Rows.Count} sản phẩm";
			_lblSummary.ForeColor = ((dataTable.Rows.Count == 0) ? Theme.Danger : Theme.Success);
			ShowDetail();
		}
		catch (Exception ex)
		{
			_lblSummary.Text = "Lỗi tra cứu: " + Db.ErrorMessage(ex);
			_lblSummary.ForeColor = Theme.Danger;
		}
	}

	private static int? NullableInt(object? value)
	{
		if (value == null || value == DBNull.Value)
		{
			return null;
		}
		return Convert.ToInt32(value);
	}

	private void ClearFilters()
	{
		_txtKeyword.Clear();
		_txtSize.Clear();
		_cboCategory.SelectedIndex = 0;
		_cboBrand.SelectedIndex = 0;
		_cboCustomer.SelectedIndex = 0;
		_cboStatus.SelectedIndex = 0;
		_numFrom.Value = 0m;
		_numTo.Value = 0m;
		Search();
	}

	private void ShowDetail()
	{
		if (_grid.CurrentRow == null || _current.Rows.Count == 0)
		{
			_lblDetail.Text = "Chọn một dòng trong kết quả để xem chi tiết.";
			_lblDetail.ForeColor = Theme.Muted;
			return;
		}
		DataRowView dataRowView = (DataRowView)_grid.CurrentRow.DataBoundItem;
		string value = ((dataRowView["GiaDangBan"] is DBNull) ? "—" : (Convert.ToDecimal(dataRowView["GiaDangBan"]).ToString("#,##0") + " đ"));
		string value2 = ((dataRowView["NgayDangBan"] is DBNull) ? "—" : Convert.ToDateTime(dataRowView["NgayDangBan"]).ToString("dd/MM/yyyy"));
		string value3 = ((dataRowView["TenThuongHieu"] is DBNull) ? "(không thương hiệu)" : Convert.ToString(dataRowView["TenThuongHieu"]));
		_lblDetail.ForeColor = Theme.Ink;
		_lblDetail.Text = $"{dataRowView["TenSP"]}  —  {value}  •  {dataRowView["TrangThaiBan"]}\r\nDanh mục: {dataRowView["TenDanhMuc"]}  •  Thương hiệu: {value3}  •  Size: {dataRowView["KichThuoc"]}  •  Màu: {dataRowView["MauSac"]}\r\nNgười ký gửi: {dataRowView["TenNguoiKyGui"]} ({dataRowView["DienThoaiNguoiKyGui"]})  •  Phiếu #{dataRowView["MaPKG"]} ngày {Convert.ToDateTime(dataRowView["NgayKyGui"]):dd/MM/yyyy}  •  Nhân viên: {dataRowView["TenNhanVienTiepNhan"]}  •  Đăng bán: {value2}";
	}

	private void ListSelectedProduct()
	{
		if (_current.Rows.Count == 0 || !(_grid.CurrentRow?.DataBoundItem is DataRowView dataRowView))
		{
			MessageBox.Show("Chọn một sản phẩm trong danh sách kết quả để đăng bán.", "Đăng bán sản phẩm", MessageBoxButtons.OK, MessageBoxIcon.Asterisk);
			return;
		}
		int num = Convert.ToInt32(dataRowView["MaSP"]);
		string text = Convert.ToString(dataRowView["TenSP"]) ?? "";
		string text2 = Convert.ToString(dataRowView["TrangThaiTiepNhan"]) ?? "";
		string text3 = ((dataRowView["TrangThaiBan"] is DBNull) ? null : Convert.ToString(dataRowView["TrangThaiBan"]));
		decimal currentPrice = ((dataRowView["GiaDangBan"] is DBNull) ? 0m : Convert.ToDecimal(dataRowView["GiaDangBan"]));
		if (text2 != "Đã chấp nhận")
		{
			MessageBox.Show("Chỉ được đăng bán sản phẩm đã được chấp nhận. Hãy xét duyệt tại trang Xét duyệt ký gửi trước.", "Đăng bán sản phẩm", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
			return;
		}
		if (!(text3 == "Chưa đăng bán") && !(text3 == "Đang bán"))
		{
			MessageBox.Show("Chỉ đăng bán sản phẩm đã chấp nhận và chưa đăng bán.", "Đăng bán sản phẩm", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
			return;
		}
		Form form = base.Parent?.FindForm() ?? FindForm();
		using frmDangBanSanPham frmDangBanSanPham2 = new frmDangBanSanPham(text, currentPrice);
		DialogResult dialogResult = ((form == null) ? frmDangBanSanPham2.ShowDialog() : frmDangBanSanPham2.ShowDialog(form));
		if (dialogResult != DialogResult.OK)
		{
			return;
		}
		try
		{
			SqlParameter[] ps = new SqlParameter[2]
			{
				Db.Param("@MaSP", num),
				Db.Param("@GiaDangBan", frmDangBanSanPham2.Price)
			};
			Db.Execute("EXEC dbo.sp_DangBanSanPham @MaSP, @GiaDangBan", ps);
			string text4 = ((text3 == "Đang bán") ? $"Đã cập nhật giá đăng bán “{text}” thành {frmDangBanSanPham2.Price:#,##0} đ." : $"Đã đăng bán “{text}” với giá {frmDangBanSanPham2.Price:#,##0} đ. Sản phẩm hiện ở trạng thái Đang bán.");
			MessageBox.Show(text4, "Đăng bán thành công", MessageBoxButtons.OK, MessageBoxIcon.Asterisk);
			Search();
		}
		catch (Exception ex)
		{
			MessageBox.Show(Db.ErrorMessage(ex), "Không thể đăng bán", MessageBoxButtons.OK, MessageBoxIcon.Hand);
		}
	}

	private void ReturnSelectedProduct()
	{
		if (_current.Rows.Count == 0 || !(_grid.CurrentRow?.DataBoundItem is DataRowView dataRowView))
		{
			MessageBox.Show("Chọn một sản phẩm trong danh sách kết quả để trả lại người ký gửi.", "Trả hàng", MessageBoxButtons.OK, MessageBoxIcon.Asterisk);
			return;
		}
		int num = Convert.ToInt32(dataRowView["MaSP"]);
		string value = Convert.ToString(dataRowView["TenSP"]) ?? "";
		string value2 = Convert.ToString(dataRowView["TenNguoiKyGui"]) ?? "người ký gửi";
		string text = Convert.ToString(dataRowView["TrangThaiTiepNhan"]) ?? "";
		string text2 = ((dataRowView["TrangThaiBan"] is DBNull) ? null : Convert.ToString(dataRowView["TrangThaiBan"]));
		if (text != "Đã chấp nhận" || (!(text2 == "Chưa đăng bán") && !(text2 == "Đang bán")))
		{
			MessageBox.Show("Chỉ trả lại được sản phẩm đã chấp nhận và đang ở trạng thái Chưa đăng bán hoặc Đang bán.\r\nSản phẩm đang giữ, đã bán hoặc đã trả lại thì không trả lại được.", "Không thể trả hàng", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
			return;
		}
		DialogResult dialogResult = MessageBox.Show($"Người ký gửi {value2} không ký gửi nữa — trả sản phẩm “{value}”?\r\n\r\n" + "Sản phẩm sẽ chuyển sang trạng thái Đã trả lại và không còn bán trên sàn.", "Trả hàng cho người ký gửi", MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2);
		if (dialogResult != DialogResult.Yes)
		{
			return;
		}
		try
		{
			Db.Execute("EXEC dbo.sp_TraHang @MaSP", Db.Param("@MaSP", num));
			MessageBox.Show($"Đã trả sản phẩm “{value}” cho {value2}.", "Trả hàng thành công", MessageBoxButtons.OK, MessageBoxIcon.Asterisk);
			Search();
		}
		catch (Exception ex)
		{
			MessageBox.Show(Db.ErrorMessage(ex), "Không thể trả hàng", MessageBoxButtons.OK, MessageBoxIcon.Hand);
		}
	}

	private void Export()
	{
		string text = ExportCore();
		if (text != null)
		{
			MessageBox.Show("Đã xuất Excel:\n" + text, "Xuất thành công", MessageBoxButtons.OK, MessageBoxIcon.Asterisk);
		}
	}

	internal string? ExportForDemo()
	{
		return ExportCore();
	}

	private string? ExportCore()
	{
		if (_current.Rows.Count == 0)
		{
			MessageBox.Show("Không có dữ liệu để xuất. Hãy tìm kiếm trước.", "Xuất Excel", MessageBoxButtons.OK, MessageBoxIcon.Asterisk);
			return null;
		}
		try
		{
			DataTable dataTable = _current.DefaultView.ToTable(false, "MaSP", "TenSP", "TenDanhMuc", "TenThuongHieu", "KichThuoc", "MauSac", "ChatLieu", "TinhTrang", "GiaDeXuat", "GiaDangBan", "TrangThaiTiepNhan", "TrangThaiBan", "NgayDangBan", "MaPKG", "NgayKyGui", "TenNguoiKyGui", "DienThoaiNguoiKyGui", "TenNhanVienTiepNhan");
			Dictionary<string, string> dictionary = new Dictionary<string, string>
			{
				["MaSP"] = "Mã SP",
				["TenSP"] = "Tên sản phẩm",
				["TenDanhMuc"] = "Danh mục",
				["TenThuongHieu"] = "Thương hiệu",
				["KichThuoc"] = "Kích thước",
				["MauSac"] = "Màu sắc",
				["ChatLieu"] = "Chất liệu",
				["TinhTrang"] = "Tình trạng",
				["GiaDeXuat"] = "Giá khách đề xuất",
				["GiaDangBan"] = "Giá đăng bán",
				["TrangThaiTiepNhan"] = "Duyệt",
				["TrangThaiBan"] = "Trạng thái bán",
				["NgayDangBan"] = "Ngày đăng bán",
				["MaPKG"] = "Mã phiếu",
				["NgayKyGui"] = "Ngày ký gửi",
				["TenNguoiKyGui"] = "Người ký gửi",
				["DienThoaiNguoiKyGui"] = "SĐT",
				["TenNhanVienTiepNhan"] = "Nhân viên tiếp nhận"
			};
			foreach (KeyValuePair<string, string> item in dictionary)
			{
				dataTable.Columns[item.Key].Caption = item.Value;
			}
			return ExcelExporter.Export(dataTable, "Danh sách sản phẩm ký gửi", $"Kết quả tra cứu ngày {DateTime.Now:dd/MM/yyyy} — {_current.Rows.Count} sản phẩm", "tra-cuu-san-pham", "Nhân viên tư vấn", "Khách hàng / Quản lý cửa hàng", Array.Empty<(string, string)>(), new string[2] { "GiaDeXuat", "GiaDangBan" });
		}
		catch (Exception ex)
		{
			MessageBox.Show("Không xuất được Excel: " + ex.Message, "Lỗi", MessageBoxButtons.OK, MessageBoxIcon.Hand);
			return null;
		}
	}

	public void PrepareCapture()
	{
		_txtKeyword.Text = "Zara";
		_cboStatus.SelectedIndex = 0;
		_cboCategory.SelectedIndex = 0;
		_cboBrand.SelectedIndex = 0;
		_cboCustomer.SelectedIndex = 0;
		Search();
	}
}
