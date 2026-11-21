using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace QuanLyKyGui;

internal static class Theme
{
	public static readonly Color Ink = ColorTranslator.FromHtml("#23212A");

	public static readonly Color Muted = ColorTranslator.FromHtml("#746E66");

	public static readonly Color Canvas = ColorTranslator.FromHtml("#F5F2EC");

	public static readonly Color Surface = Color.White;

	public static readonly Color Line = ColorTranslator.FromHtml("#E1D9CC");

	public static readonly Color Accent = ColorTranslator.FromHtml("#7C1F35");

	public static readonly Color AccentSoft = ColorTranslator.FromHtml("#F6E9EC");

	public static readonly Color Gold = ColorTranslator.FromHtml("#A9822F");

	public static readonly Color GoldSoft = ColorTranslator.FromHtml("#F8F1DF");

	public static readonly Color Success = ColorTranslator.FromHtml("#2C6B4F");

	public static readonly Color SuccessSoft = ColorTranslator.FromHtml("#E8F3EC");

	public static readonly Color Danger = ColorTranslator.FromHtml("#A32B22");

	public static readonly Color DangerSoft = ColorTranslator.FromHtml("#FBEAE8");

	public static readonly Color Warning = ColorTranslator.FromHtml("#8A5B00");

	public static readonly Color WarningSoft = ColorTranslator.FromHtml("#FBF3DF");

	public static readonly Color HeaderBg = ColorTranslator.FromHtml("#2B2530");

	public static readonly Font Body = new Font("Segoe UI", 9.75f);

	public static readonly Font Small = new Font("Segoe UI", 8.75f);

	public static readonly Font Bold = new Font("Segoe UI Semibold", 9.75f);

	public static readonly Font H1 = new Font("Segoe UI Semibold", 19f);

	public static readonly Font H2 = new Font("Segoe UI Semibold", 13.5f);

	public static readonly Font H3 = new Font("Segoe UI Semibold", 10.5f);

	public static readonly Font Mono = new Font("Consolas", 9f);

	public static Label Label(string text, bool bold = false, Color? color = null, float? size = null)
	{
		return new Label
		{
			Text = text,
			AutoSize = true,
			Font = (bold ? Bold : Body),
			ForeColor = (color ?? Ink),
			Margin = new Padding(0, 4, 0, 4)
		};
	}

	public static Label Caption(string text)
	{
		return new Label
		{
			Text = text,
			AutoSize = true,
			Font = Small,
			ForeColor = Muted,
			Margin = new Padding(0, 2, 0, 2)
		};
	}

	public static TextBox TextBox(string? text = null, int width = 220)
	{
		return new TextBox
		{
			Text = (text ?? string.Empty),
			Width = width,
			Font = Body,
			BorderStyle = BorderStyle.FixedSingle,
			Margin = new Padding(0, 4, 12, 10)
		};
	}

	public static ComboBox Combo(int width = 220)
	{
		return new ComboBox
		{
			Width = width,
			Font = Body,
			DropDownStyle = ComboBoxStyle.DropDownList,
			FlatStyle = FlatStyle.Standard,
			BackColor = Surface,
			ForeColor = Ink,
			Margin = new Padding(0, 4, 12, 10)
		};
	}

	public static DateTimePicker DatePicker(int width = 160)
	{
		return new DateTimePicker
		{
			Width = width,
			Font = Body,
			Format = DateTimePickerFormat.Custom,
			CustomFormat = "dd/MM/yyyy",
			Margin = new Padding(0, 4, 12, 10)
		};
	}

	/// <summary>
	/// Ô nhập số tiền.
	/// KHÔNG đặt trần ở đây: NumericUpDown sẽ ÂM THẦM cắt giá trị về Maximum khi người
	/// dùng gõ số lớn hơn (không báo lỗi) — đó chính là lỗi "gõ 600 triệu thành 0".
	/// Trần nghiệp vụ kiểm bằng <see cref="PriceInRange"/> / <see cref="MoneyInRange"/>
	/// để có thông báo rõ ràng.
	/// </summary>
	public static NumericUpDown Number(decimal max = decimal.MaxValue, int width = 160)
	{
		return new NumericUpDown
		{
			Width = width,
			Font = Body,
			Maximum = max,
			Minimum = 0m,
			Increment = 50000m,
			ThousandsSeparator = true,
			Margin = new Padding(0, 4, 12, 10)
		};
	}

	/// <summary>Trần giá nghiệp vụ của shop: giá đề xuất, giá đăng bán, giá chốt đơn.</summary>
	public const decimal PriceMax = 500_000_000m;

	/// <summary>Giới hạn vật lý của cột tiền trong CSDL: DECIMAL(12,0).</summary>
	public const decimal MoneyMax = 999_999_999_999m;

	/// <summary>Kiểm tra giá theo trần nghiệp vụ, trả thông báo lỗi thay vì cắt bớt.</summary>
	public static bool PriceInRange(decimal value, out string? error)
	{
		if (value < 0m)
		{
			error = "Giá không được âm.";
			return false;
		}
		if (value > PriceMax)
		{
			error = $"Giá không được vượt quá {PriceMax:#,##0} đ.";
			return false;
		}
		error = null;
		return true;
	}

	/// <summary>Kiểm tra số tiền thu theo giới hạn CSDL, trả thông báo lỗi thay vì cắt bớt.</summary>
	public static bool MoneyInRange(decimal value, out string? error)
	{
		if (value < 0m)
		{
			error = "Số tiền không được âm.";
			return false;
		}
		if (value > MoneyMax)
		{
			error = $"Số tiền vượt giới hạn cho phép ({MoneyMax:#,##0} đ).";
			return false;
		}
		error = null;
		return true;
	}

	/// <summary>
	/// Đọc số tiền người dùng đã gõ, kể cả khi CHƯA nhấn Enter hay rời ô.
	/// NumericUpDown chỉ cập nhật .Value khi mất focus, nên đọc thẳng .Value
	/// ngay sau khi gõ sẽ lấy giá trị cũ.
	/// Không kẹp về Maximum/Minimum — trả đúng số đã gõ để nơi gọi báo lỗi rõ ràng.
	/// </summary>
	public static decimal MoneyValue(NumericUpDown input)
	{
		var raw = input.Text;
		if (string.IsNullOrWhiteSpace(raw)) return input.Value;

		var digits = raw.Replace(".", string.Empty)
		                .Replace(",", string.Empty)
		                .Replace(" ", string.Empty)
		                .Replace("\u00A0", string.Empty)
		                .Trim();

		return digits.Length > 0 && decimal.TryParse(digits, out var typed) ? typed : input.Value;
	}

	public static Button PrimaryButton(string text, int width = 170)
	{
		Button button = BaseButton(text, width);
		button.BackColor = Accent;
		button.ForeColor = Color.White;
		button.FlatAppearance.MouseOverBackColor = ColorTranslator.FromHtml("#9A2A43");
		button.FlatAppearance.BorderSize = 0;
		return button;
	}

	public static Button GoldButton(string text, int width = 170)
	{
		Button button = BaseButton(text, width);
		button.BackColor = Gold;
		button.ForeColor = Color.White;
		button.FlatAppearance.MouseOverBackColor = ColorTranslator.FromHtml("#BE9539");
		button.FlatAppearance.BorderSize = 0;
		return button;
	}

	public static Button GhostButton(string text, int width = 140)
	{
		Button button = BaseButton(text, width);
		button.BackColor = Surface;
		button.ForeColor = Ink;
		button.FlatAppearance.BorderColor = Line;
		button.FlatAppearance.BorderSize = 1;
		button.FlatAppearance.MouseOverBackColor = ColorTranslator.FromHtml("#F2EDE4");
		return button;
	}

	private static Button BaseButton(string text, int width)
	{
		return new Button
		{
			Text = text,
			Width = width,
			Height = 34,
			Font = Bold,
			FlatStyle = FlatStyle.Flat,
			Cursor = Cursors.Hand,
			Margin = new Padding(0, 4, 8, 8),
			UseVisualStyleBackColor = false
		};
	}

	public static Panel Actions(params Control[] buttons)
	{
		Panel panel = new Panel
		{
			BackColor = Color.Transparent,
			Height = 42,
			Margin = new Padding(0, 4, 0, 0)
		};
		int num = 0;
		foreach (Control control in buttons)
		{
			control.Location = new Point(num, 2);
			control.Margin = new Padding(0);
			panel.Controls.Add(control);
			num += control.Width + 8;
		}
		panel.Width = Math.Max(0, num - 8);
		panel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
		return panel;
	}

	public static void StyleGrid(DataGridView g, bool fill = true)
	{
		g.BackgroundColor = Surface;
		g.BorderStyle = BorderStyle.None;
		g.GridColor = ColorTranslator.FromHtml("#EDE7DD");
		g.RowHeadersVisible = false;
		g.AllowUserToAddRows = false;
		g.AllowUserToDeleteRows = false;
		g.AllowUserToResizeRows = false;
		g.ReadOnly = true;
		g.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
		g.MultiSelect = false;
		g.AutoSizeColumnsMode = ((!fill) ? DataGridViewAutoSizeColumnsMode.None : DataGridViewAutoSizeColumnsMode.Fill);
		g.EnableHeadersVisualStyles = false;
		g.ColumnHeadersDefaultCellStyle.BackColor = ColorTranslator.FromHtml("#F1ECE3");
		g.ColumnHeadersDefaultCellStyle.ForeColor = Ink;
		g.ColumnHeadersDefaultCellStyle.Font = new Font("Segoe UI Semibold", 8.75f);
		g.ColumnHeadersDefaultCellStyle.Padding = new Padding(6, 0, 6, 0);
		g.ColumnHeadersDefaultCellStyle.WrapMode = DataGridViewTriState.True;
		g.ColumnHeadersDefaultCellStyle.SelectionBackColor = ColorTranslator.FromHtml("#F1ECE3");
		g.ColumnHeadersDefaultCellStyle.SelectionForeColor = Ink;
		g.ColumnHeadersHeight = 44;
		g.ColumnHeadersHeightSizeMode = DataGridViewColumnHeadersHeightSizeMode.DisableResizing;
		g.DefaultCellStyle.Font = new Font("Segoe UI", 9f);
		g.DefaultCellStyle.ForeColor = Ink;
		g.DefaultCellStyle.SelectionBackColor = AccentSoft;
		g.DefaultCellStyle.SelectionForeColor = Ink;
		g.DefaultCellStyle.Padding = new Padding(6, 0, 6, 0);
		g.RowTemplate.Height = 28;
		g.AlternatingRowsDefaultCellStyle.BackColor = ColorTranslator.FromHtml("#FBF9F5");
	}

	public static void MoneyColumn(DataGridViewColumn? col)
	{
		if (col != null)
		{
			col.DefaultCellStyle.Format = "#,##0";
			col.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight;
		}
	}

	public static void NumberColumn(DataGridViewColumn? col)
	{
		if (col != null)
		{
			col.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight;
		}
	}

	public static DataGridViewTextBoxColumn TextColumn(string name, string header, int fillWeight = 100, bool money = false, bool hidden = false)
	{
		DataGridViewTextBoxColumn dataGridViewTextBoxColumn = new DataGridViewTextBoxColumn
		{
			Name = name,
			DataPropertyName = name,
			HeaderText = header,
			FillWeight = fillWeight,
			Visible = !hidden
		};
		if (money)
		{
			dataGridViewTextBoxColumn.DefaultCellStyle.Format = "#,##0";
			dataGridViewTextBoxColumn.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight;
		}
		return dataGridViewTextBoxColumn;
	}

	public static TableLayoutPanel Stack(params Control[] controls)
	{
		TableLayoutPanel tableLayoutPanel = new TableLayoutPanel
		{
			Dock = DockStyle.Fill,
			ColumnCount = 1,
			RowCount = controls.Length,
			AutoSize = false,
			BackColor = Color.Transparent
		};
		tableLayoutPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
		for (int i = 0; i < controls.Length; i++)
		{
			tableLayoutPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
			tableLayoutPanel.Controls.Add(controls[i], 0, i);
		}
		return tableLayoutPanel;
	}

	public static Panel Row(params Control[] controls)
	{
		Panel panel = new Panel
		{
			AutoSize = true,
			Dock = DockStyle.Top,
			BackColor = Color.Transparent
		};
		int num = 0;
		foreach (Control control in controls)
		{
			control.Location = new Point(num, 0);
			panel.Controls.Add(control);
			num += control.Width + 10;
		}
		panel.Height = ((controls.Length != 0) ? (controls.Max((Control c) => c.Height) + 6) : 0);
		return panel;
	}

	public static void Fill(Control parent, Control child, Padding? padding = null)
	{
		child.Dock = DockStyle.Fill;
		if (padding.HasValue)
		{
			child.Margin = padding.Value;
		}
		parent.Controls.Add(child);
	}
}
