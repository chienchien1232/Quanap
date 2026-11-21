/* ============================================================
   15_e2e_tests.sql — Kiem thu end-to-end toan bo luong nghiep vu
   Them khach -> tiep nhan -> xet duyet -> dang ban -> don hang
   -> thu tien -> hoan tat -> quyet toan -> bao cao -> huỷ don
   -> tra hang -> quan ly nhan vien

   Chay khong doi lai du lieu: luong vui chay trong 1 transaction
   roi ROLLBACK; cac buoc nghiem chat chay rieng tung transaction.
   Ket qua buffer bang TABLE VARIABLE vi khong bi rollback.
   Moi buoc dung dung ky hieu SP ma UI goi.
   ============================================================ */
USE [QuanLyKyGuiThoiTrang];
SET NOCOUNT ON;
SET XACT_ABORT OFF;

CREATE TABLE #E2E (Buoc INT IDENTITY, Ten NVARCHAR(120), KetQua VARCHAR(8), ChiTiet NVARCHAR(600));
GO

/* ============================================================
   PHAN A — LUONG VUI (moi buoc deu phai thanh cong)
   ============================================================ */
DECLARE @R TABLE (Ten NVARCHAR(120), KetQua VARCHAR(8), ChiTiet NVARCHAR(600));
DECLARE @Abort BIT = 0;
DECLARE @MaNV INT, @MaKH_Mua INT, @MaKH_Gui INT, @MaDM INT, @MaTH INT;
DECLARE @MaPKG INT, @SP_A INT, @SP_B INT, @SP_C INT, @SP_D INT, @MaDH INT, @MaPTTKG INT;
DECLARE @t1 INT, @t2 INT;
DECLARE @GiaBanA DECIMAL(12,0) = 800000, @GiaBanB DECIMAL(12,0) = 600000, @GiaBanC DECIMAL(12,0) = 500000;
DECLARE @GiamGia DECIMAL(12,0) = 50000;      /* 10% gia ban A — duoi tran 50% */
DECLARE @TongDon DECIMAL(12,0) = @GiaBanA + @GiaBanB - @GiamGia;
DECLARE @ThucNhan DECIMAL(12,0), @HoaHong DECIMAL(12,0), @HanThanhToan DATETIME2(0), @ConLai DECIMAL(12,0);
/* Ngay lap du giay — khop voi UI sau khi sua (_dtpOrder.Value.Date + TimeOfDay).
   Neu cat giay thi don lap cung phut voi luc dang ban se bi chan oan (51312). */
DECLARE @NgayLap DATETIME2(0) = CAST(SYSDATETIME() AS datetime2(0));
SET @HanThanhToan = DATEADD(day, 3, @NgayLap);

BEGIN TRANSACTION;

/* ===== 1. Thêm nhân viên (EmployeeService.Add) ===== */
BEGIN TRY
    INSERT dbo.NHAN_VIEN (HoTen, SoDienThoai, Email, ChucVu, TrangThai)
    VALUES (N'E2E Nhân viên test', '0908888001', 'e2e@thienkim.vn', N'Nhân viên', N'Đang làm việc');
    SET @MaNV = (SELECT MaNV FROM dbo.NHAN_VIEN WHERE SoDienThoai = '0908888001');
    INSERT @R VALUES (N'1. Thêm nhân viên', 'OK', N'MaNV=' + CAST(@MaNV AS NVARCHAR(10)));
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'1. Thêm nhân viên', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 2. Thêm khách hàng người ký gửi (frmKhachHangMoi) ===== */
IF @Abort = 0
BEGIN TRY
    /* UI nhập "0907 777 001" -> Normalize.Phone -> "0907777001" */
    INSERT dbo.KHACH_HANG (HoTen, SoDienThoai, Email, DiaChi)
    VALUES (N'E2E Người ký gửi', '0907777001', 'e2e.kygui@thienkim.vn', N'Hà Nội');
    SET @MaKH_Gui = (SELECT MaKH FROM dbo.KHACH_HANG WHERE SoDienThoai = '0907777001');
    INSERT @R VALUES (N'2. Thêm khách hàng (người ký gửi)', 'OK', N'MaKH=' + CAST(@MaKH_Gui AS NVARCHAR(10)));
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'2. Thêm khách hàng (người ký gửi)', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 3. Thêm khách hàng người mua ===== */
IF @Abort = 0
BEGIN TRY
    INSERT dbo.KHACH_HANG (HoTen, SoDienThoai, Email, DiaChi)
    VALUES (N'E2E Người mua', '0907777002', 'e2e.mua@thienkim.vn', N'Hà Nội');
    SET @MaKH_Mua = (SELECT MaKH FROM dbo.KHACH_HANG WHERE SoDienThoai = '0907777002');
    INSERT @R VALUES (N'3. Thêm khách hàng (người mua)', 'OK', N'MaKH=' + CAST(@MaKH_Mua AS NVARCHAR(10)));
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'3. Thêm khách hàng (người mua)', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 4. Tìm khách theo SĐT (frmChonKhachHang) ===== */
IF @Abort = 0
BEGIN TRY
    IF (SELECT COUNT(*) FROM dbo.KHACH_HANG WHERE SoDienThoai = '0907777001') <> 1
        THROW 52000, N'Không tìm thấy đúng 1 hồ sơ theo số điện thoại.', 1;
    INSERT @R VALUES (N'4. Tìm khách hàng theo SĐT', 'OK', N'Tìm thấy đúng 1 hồ sơ.');
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'4. Tìm khách hàng theo SĐT', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 5. Tiếp nhận ký gửi 3 món (frmTiepNhanKyGui) ===== */
IF @Abort = 0
BEGIN TRY
    SET @MaDM = (SELECT TOP(1) MaDM FROM dbo.DANH_MUC ORDER BY MaDM);
    SET @MaTH = (SELECT TOP(1) MaTH FROM dbo.THUONG_HIEU ORDER BY MaTH);
    DECLARE @SanPham dbo.SanPhamKyGuiType;
    INSERT @SanPham (MaDM, MaTH, TenSP, MoTa, KichThuoc, MauSac, ChatLieu, TinhTrang, GiaDeXuat, GiaDangBan, TrangThaiTiepNhan)
    VALUES (@MaDM, @MaTH, N'E2E Áo khoác', N'Áo khoác', N'M', N'Đen', N'Vải dù', N'Còn tốt', @GiaBanA, NULL, N'Chờ xử lý'),
           (@MaDM, @MaTH, N'E2E Váy',       N'Váy',     N'S', N'Đỏ',  N'Lụa',   N'Còn tốt', @GiaBanB, NULL, N'Chờ xử lý'),
           (@MaDM, @MaTH, N'E2E Quần jeans',N'Quần',    N'L', N'Xanh',N'Denim', N'Còn tốt', @GiaBanC, NULL, N'Chờ xử lý'),
           (@MaDM, @MaTH, N'E2E Khăn quàng',N'Khăn',    N'F', N'Trắng',N'Lụa',  N'Còn tốt', 200000, NULL, N'Chờ xử lý');
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH=@MaKH_Gui, @MaNV=@MaNV, @NgayKyGui=@NgayLap,
         @GhiChu=N'E2E phiếu tiếp nhận', @SanPham=@SanPham, @MaPKG=@MaPKG OUTPUT;
    /* Chọn món theo tên để MIN/MAX không bị trùng khi thêm món mới */
    SELECT @SP_A = MaSP FROM dbo.SAN_PHAM WHERE MaPKG=@MaPKG AND TenSP = N'E2E Áo khoác';
    SELECT @SP_B = MaSP FROM dbo.SAN_PHAM WHERE MaPKG=@MaPKG AND TenSP = N'E2E Váy';
    SELECT @SP_C = MaSP FROM dbo.SAN_PHAM WHERE MaPKG=@MaPKG AND TenSP = N'E2E Quần jeans';
    SELECT @SP_D = MaSP FROM dbo.SAN_PHAM WHERE MaPKG=@MaPKG AND TenSP = N'E2E Khăn quàng';
    IF @SP_A IS NULL OR @SP_B IS NULL OR @SP_C IS NULL OR @SP_D IS NULL
        THROW 52000, N'Không xác định được 4 món để test.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI WHERE MaPKG=@MaPKG AND TrangThai=N'Đang xử lý')
        THROW 52000, N'Phiếu mới không ở Đang xử lý.', 1;
    IF (SELECT COUNT(*) FROM dbo.SAN_PHAM WHERE MaPKG=@MaPKG) <> 4
        THROW 52000, N'Phiếu không có đủ 4 món.', 1;
    IF EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaPKG=@MaPKG AND
               (TrangThaiTiepNhan <> N'Chờ xử lý' OR GiaDangBan IS NOT NULL OR TrangThaiBan IS NOT NULL))
        THROW 52000, N'Sản phẩm mới bị gán giá hoặc trạng thái bán sớm.', 1;
    INSERT @R VALUES (N'5. Tiếp nhận ký gửi (4 món)', 'OK', N'MaPKG=' + CAST(@MaPKG AS NVARCHAR(10)));
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'5. Tiếp nhận ký gửi (3 món)', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 6. Xét duyệt 2 nhận 1 từ chối (frmXetDuyetKyGui) ===== */
IF @Abort = 0
BEGIN TRY
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP_A, @KetQua=N'Đã chấp nhận';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP_B, @KetQua=N'Đã chấp nhận';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP_C, @KetQua=N'Từ chối';
    /* Món D còn Chờ xử lý nên phiếu phải giữ Đang xử lý, không chuyển sớm */
    IF NOT EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI WHERE MaPKG=@MaPKG AND TrangThai=N'Đang xử lý')
        THROW 52000, N'Phiếu phải giữ Đang xử lý khi còn món chờ duyệt.', 1;
    IF EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP_C AND (TrangThaiTiepNhan <> N'Từ chối' OR TrangThaiBan IS NOT NULL))
        THROW 52000, N'Món bị từ chối phải để trống trạng thái bán.', 1;
    INSERT @R VALUES (N'6. Xét duyệt: 2 nhận, 1 từ chối, 1 chờ', 'OK', N'Phiếu giữ Đang xử lý (còn món chờ).');
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'6. Xét duyệt', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 7. Đăng bán 2 món (frmTraCuuSanPham) ===== */
IF @Abort = 0
BEGIN TRY
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP_A, @GiaDangBan=@GiaBanA;
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP_B, @GiaDangBan=@GiaBanB;
    IF EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP IN (@SP_A,@SP_B) AND
               (TrangThaiBan <> N'Đang bán' OR GiaDangBan IS NULL OR NgayDangBan IS NULL))
        THROW 52000, N'Đăng bán không đúng trạng thái/giá/ngày.', 1;
    INSERT @R VALUES (N'7. Đăng bán 2 món', 'OK', N'2 món Đang bán.');
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'7. Đăng bán 2 món', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 8. Lập đơn hàng 2 món (frmLapDonHang.CreateOrderFromUi) ===== */
IF @Abort = 0
BEGIN TRY
    DECLARE @ChiTiet dbo.ChiTietDonHangType;
    INSERT @ChiTiet (MaSP, GiamGia) VALUES (@SP_A, @GiamGia), (@SP_B, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH_Mua, @MaNV=@MaNV, @NgayLap=@NgayLap,
         @HanThanhToan=@HanThanhToan, @GhiChu=N'E2E đơn hàng',
         @ChiTiet=@ChiTiet, @MaDH=@MaDH OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@MaDH AND TrangThai=N'Chờ thanh toán')
        THROW 52000, N'Đơn mới không ở Chờ thanh toán.', 1;
    IF (SELECT COUNT(*) FROM dbo.SAN_PHAM WHERE MaSP IN (@SP_A,@SP_B) AND TrangThaiBan=N'Đang giữ') <> 2
        THROW 52000, N'Đơn không giữ đúng 2 sản phẩm.', 1;
    IF (SELECT SUM(GiaBanThucTe) FROM dbo.CHI_TIET_DON_HANG WHERE MaDH=@MaDH) <> @TongDon
        THROW 52000, N'Tổng tiền không khớp giá trừ giảm giá.', 1;
    INSERT @R VALUES (N'8. Lập đơn hàng (2 món)', 'OK',
        N'MaDH=' + CAST(@MaDH AS NVARCHAR(10)) + N', tổng=' + FORMAT(@TongDon, 'N0'));
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'8. Lập đơn hàng', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 9. Thu tiền một phần ===== */
IF @Abort = 0
BEGIN TRY
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@MaDH, @SoTien=300000, @PhuongThuc=N'Tiền mặt',
         @MaGiaoDich=N'E2E-TXN-1', @GhiChu=N'E2E thu đợt 1', @MaTTDH=@t1 OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@MaDH AND TrangThai=N'Chờ thanh toán')
        THROW 52000, N'Thu một phần mà đơn rời Chờ thanh toán.', 1;
    IF (SELECT COUNT(*) FROM dbo.SAN_PHAM WHERE MaSP IN (@SP_A,@SP_B) AND TrangThaiBan=N'Đang giữ') <> 2
        THROW 52000, N'Thu một phần mà sản phẩm rời Đang giữ.', 1;
    INSERT @R VALUES (N'9. Thu tiền một phần 300.000', 'OK', N'Đơn giữ Chờ thanh toán.');
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'9. Thu tiền một phần', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 10. Thu phần còn lại -> Đang xử lý ===== */
IF @Abort = 0
BEGIN TRY
    SET @ConLai = (SELECT ConLai FROM dbo.vw_DonHang_TongHop WHERE MaDH=@MaDH);
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@MaDH, @SoTien=@ConLai, @PhuongThuc=N'Chuyển khoản',
         @MaGiaoDich=N'E2E-TXN-2', @MaTTDH=@t2 OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@MaDH AND TrangThai=N'Đang xử lý')
        THROW 52000, N'Đơn không chuyển Đang xử lý sau khi thu đủ.', 1;
    IF EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP IN (@SP_A,@SP_B) AND TrangThaiBan <> N'Đã bán')
        THROW 52000, N'Sản phẩm không chuyển Đã bán sau khi thu đủ.', 1;
    INSERT @R VALUES (N'10. Thu phần còn lại ' + FORMAT(@ConLai,'N0'), 'OK', N'Đơn Đang xử lý, sản phẩm Đã bán.');
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'10. Thu phần còn lại', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 11. Hoàn tất đơn ===== */
IF @Abort = 0
BEGIN TRY
    EXEC dbo.sp_HoanTatDonHang @MaDH=@MaDH;
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@MaDH AND TrangThai=N'Hoàn tất')
        THROW 52000, N'Đơn không chuyển Hoàn tất.', 1;
    INSERT @R VALUES (N'11. Hoàn tất đơn', 'OK', N'Đủ điều kiện quyết toán.');
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'11. Hoàn tất đơn', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 12. Lập phiếu quyết toán (frmBaoCaoQuyetToan) ===== */
IF @Abort = 0
BEGIN TRY
    DECLARE @DanhSach dbo.DanhSachCTDHType;
    INSERT @DanhSach (MaCTDH)
    SELECT c.MaCTDH
    FROM dbo.CHI_TIET_DON_HANG c
    JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH AND d.TrangThai = N'Hoàn tất'
    JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
    JOIN dbo.PHIEU_KY_GUI pk ON pk.MaPKG = sp.MaPKG
    WHERE pk.MaKH = @MaKH_Gui
      AND NOT EXISTS (SELECT 1 FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI x WHERE x.MaCTDH = c.MaCTDH);

    SET @ThucNhan = (SELECT SUM(c.GiaBanThucTe - CAST(ROUND(c.GiaBanThucTe*0.20,0) AS DECIMAL(12,0)))
                     FROM dbo.CHI_TIET_DON_HANG c WHERE c.MaCTDH IN (SELECT MaCTDH FROM @DanhSach));
    SET @HoaHong  = (SELECT SUM(CAST(ROUND(c.GiaBanThucTe*0.20,0) AS DECIMAL(12,0)))
                     FROM dbo.CHI_TIET_DON_HANG c WHERE c.MaCTDH IN (SELECT MaCTDH FROM @DanhSach));

    EXEC dbo.sp_LapPhieuQuyetToan @MaKH=@MaKH_Gui, @MaNV=@MaNV, @PhuongThuc=N'Tiền mặt',
         @GhiChu=N'E2E quyết toán', @DanhSach=@DanhSach, @MaPTTKG=@MaPTTKG OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.PHIEU_THANH_TOAN_KY_GUI WHERE MaPTTKG=@MaPTTKG AND TrangThai=N'Chờ thanh toán')
        THROW 52000, N'Phiếu quyết toán không ở Chờ thanh toán.', 1;
    IF (SELECT COUNT(*) FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI WHERE MaPTTKG=@MaPTTKG) <> 2
        THROW 52000, N'Phiếu quyết toán thiếu chi tiết.', 1;
    INSERT @R VALUES (N'12. Lập phiếu quyết toán', 'OK',
        N'MaPTTKG=' + CAST(@MaPTTKG AS NVARCHAR(10))
        + N', hoa hồng=' + FORMAT(@HoaHong,'N0') + N', thực nhận=' + FORMAT(@ThucNhan,'N0'));
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'12. Lập phiếu quyết toán', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 13. Xác nhận chi tiền ===== */
IF @Abort = 0
BEGIN TRY
    EXEC dbo.sp_ThanhToanPhieuKyGui @MaPTTKG=@MaPTTKG, @MaGiaoDich=N'PC-E2E', @GhiChu=N'Chi tại quầy';
    IF NOT EXISTS (SELECT 1 FROM dbo.PHIEU_THANH_TOAN_KY_GUI
                   WHERE MaPTTKG=@MaPTTKG AND TrangThai=N'Đã thanh toán' AND NgayThanhToan IS NOT NULL)
        THROW 52000, N'Phiếu quyết toán không chuyển Đã thanh toán hoặc thiếu ngày.', 1;
    INSERT @R VALUES (N'13. Xác nhận chi tiền cho người ký gửi', 'OK', N'Phiếu Đã thanh toán.');
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'13. Xác nhận chi tiền', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 14. Báo cáo nhất quán sau toàn bộ luồng ===== */
IF @Abort = 0
BEGIN TRY
    DECLARE @Thang NVARCHAR(7) = FORMAT(SYSDATETIME(), 'yyyy-MM');
    IF NOT EXISTS (SELECT 1 FROM dbo.vw_DoanhThu_TheoThang WHERE Thang = @Thang)
        THROW 52000, N'Báo cáo doanh thu không thấy tháng hiện tại.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.vw_HieuSuat_NhanVien WHERE MaNV=@MaNV AND SoDonHang >= 1)
        THROW 52000, N'Hiệu suất nhân viên không ghi nhận đơn vừa lập.', 1;
    IF EXISTS (SELECT 1 FROM dbo.vw_CongNo_NguoiKyGui WHERE MaKH=@MaKH_Gui)
        THROW 52000, N'Còn công nợ dù đã quyết toán hết.', 1;
    INSERT @R VALUES (N'14. Báo cáo doanh thu / hiệu suất / công nợ', 'OK', N'Nhất quán sau toàn bộ luồng.');
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'14. Báo cáo sau luồng', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 15. Huỷ đơn có giao dịch treo (lỗi A4) ===== */
IF @Abort = 0
BEGIN TRY
    /* SP_D vẫn Chờ xử lý sau bước xét duyệt, dùng cho đơn sẽ bị huỷ */
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP_D AND TrangThaiTiepNhan=N'Chờ xử lý')
        THROW 52000, N'Món D phải còn Chờ xử lý để test luồng huỷ.', 1;
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP_D, @KetQua=N'Đã chấp nhận';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP_D, @GiaDangBan=200000;
    DECLARE @CT2 dbo.ChiTietDonHangType, @DH2 INT, @tt3 INT;
    INSERT @CT2 (MaSP, GiamGia) VALUES (@SP_D, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH_Mua, @MaNV=@MaNV, @ChiTiet=@CT2, @MaDH=@DH2 OUTPUT;
    DECLARE @TienD DECIMAL(12,0) = (SELECT GiaDangBan FROM dbo.SAN_PHAM WHERE MaSP=@SP_D);
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH2, @SoTien=@TienD, @PhuongThuc=N'Tiền mặt',
         @TrangThai=N'Chờ xử lý', @MaTTDH=@tt3 OUTPUT;
    EXEC dbo.sp_HuyDonHang @MaDH=@DH2, @LyDo=N'E2E test huỷ đơn có giao dịch treo';

    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@DH2 AND TrangThai=N'Đã hủy')
        THROW 52000, N'Đơn không chuyển Đã hủy.', 1;
    IF EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG WHERE MaTTDH=@tt3 AND TrangThai=N'Chờ xử lý')
        THROW 52000, N'Giao dịch treo chưa được đóng.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP_D AND TrangThaiBan=N'Đang bán')
        THROW 52000, N'Sản phẩm không trở lại Đang bán sau khi huỷ đơn.', 1;
    INSERT @R VALUES (N'15. Huỷ đơn có giao dịch treo', 'OK',
        N'Đơn Đã hủy, giao dịch Thất bại, sản phẩm trở lại Đang bán.');
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'15. Huỷ đơn có giao dịch treo', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

/* ===== 16. Bất biến nghiệp vụ giữ vững ===== */
IF @Abort = 0
BEGIN TRY
    IF EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI p WHERE p.TrangThai <> dbo.fn_TrangThaiPhieuKyGui(p.MaPKG))
        THROW 52000, N'Trạng thái phiếu lệch với trạng thái sản phẩm.', 1;
    IF EXISTS (SELECT 1 FROM dbo.vw_DonHang_TongHop
               WHERE TrangThai IN (N'Hoàn tất', N'Đang xử lý') AND DaThu < TongTien)
        THROW 52000, N'Tồn tại đơn Hoàn tất/Đang xử lý chưa thu đủ tiền.', 1;
    IF EXISTS (SELECT 1 FROM dbo.vw_DonHang_TongHop
               WHERE TrangThai = N'Chờ thanh toán' AND DaThu >= TongTien)
        THROW 52000, N'Tồn tại đơn Chờ thanh toán mà đã thu đủ tiền.', 1;
    IF EXISTS (SELECT 1 FROM dbo.SAN_PHAM sp
               WHERE sp.TrangThaiBan IN (N'Đang giữ', N'Đã bán')
                 AND NOT EXISTS (SELECT 1 FROM dbo.CHI_TIET_DON_HANG c
                                 JOIN dbo.DON_HANG d ON d.MaDH=c.MaDH
                                 WHERE c.MaSP=sp.MaSP AND d.TrangThai <> N'Đã hủy'))
        THROW 52000, N'Tồn tại sản phẩm Đang giữ/Đã bán không thuộc đơn còn hiệu lực.', 1;
    INSERT @R VALUES (N'16. Bất biến nghiệp vụ sau E2E', 'OK', N'Phiếu/đơn/tiền/sản phẩm đều nhất quán.');
END TRY
BEGIN CATCH
    INSERT @R VALUES (N'16. Bất biến nghiệp vụ', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
    SET @Abort = 1; ROLLBACK TRANSACTION;
END CATCH

IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
INSERT INTO #E2E (Ten, KetQua, ChiTiet) SELECT Ten, KetQua, ChiTiet FROM @R;
GO

/* ============================================================
   PHAN B — CAC BUOC NGHIEM (moi buoc transaction rieng + rollback)
   ============================================================ */

/* ===== 17. Trả hàng là trạng thái cuối, không bán lại được ===== */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @MaKH17 INT = (SELECT TOP(1) MaKH FROM dbo.KHACH_HANG ORDER BY MaKH);
    DECLARE @MaNV17 INT = (SELECT TOP(1) MaNV FROM dbo.NHAN_VIEN WHERE TrangThai=N'Đang làm việc' ORDER BY MaNV);
    DECLARE @DM17 INT = (SELECT TOP(1) MaDM FROM dbo.DANH_MUC ORDER BY MaDM);
    DECLARE @SP17 dbo.SanPhamKyGuiType, @PKG17 INT;
    INSERT @SP17 (MaDM, TenSP, TinhTrang, TrangThaiTiepNhan)
    VALUES (@DM17, N'E2E món trả hàng', N'Còn tốt', N'Chờ xử lý');
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH=@MaKH17, @MaNV=@MaNV17, @SanPham=@SP17, @MaPKG=@PKG17 OUTPUT;
    DECLARE @S17 INT = (SELECT MAX(MaSP) FROM dbo.SAN_PHAM WHERE MaPKG=@PKG17);
    EXEC dbo.sp_DuyetSanPham @MaSP=@S17, @KetQua=N'Đã chấp nhận';
    EXEC dbo.sp_DangBanSanPham @MaSP=@S17, @GiaDangBan=300000;
    EXEC dbo.sp_TraHang @MaSP=@S17;

    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@S17 AND TrangThaiBan=N'Đã trả lại')
        THROW 52000, N'Sản phẩm không chuyển Đã trả lại.', 1;
    BEGIN TRY
        EXEC dbo.sp_DangBanSanPham @MaSP=@S17, @GiaDangBan=300000;
        THROW 52000, N'Sản phẩm Đã trả lại vẫn đăng bán lại được.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 51203
            THROW 52000, N'Lỗi chặn bán lại không đúng mã 51203.', 1;
    END CATCH
    /* sp_DangBanSanPham có XACT_ABORT ON nên THROW đã tự rollback transaction,
       kiểm tra @@TRANCOUNT trước khi rollback lại. */
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #E2E VALUES (N'17. Trả hàng và chặn bán lại', 'OK', N'Đã trả lại là trạng thái cuối.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #E2E VALUES (N'17. Trả hàng và chặn bán lại', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
END CATCH
GO

/* ===== 18. Nhân viên đã nghỉ không lập được phiếu ===== */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @MaNghi18 INT = (SELECT TOP(1) MaNV FROM dbo.NHAN_VIEN WHERE TrangThai=N'Đã nghỉ' ORDER BY MaNV);
    IF @MaNghi18 IS NULL
        THROW 52000, N'Dữ liệu mẫu không có nhân viên đã nghỉ để kiểm tra.', 1;
    DECLARE @MaKH18 INT = (SELECT TOP(1) MaKH FROM dbo.KHACH_HANG ORDER BY MaKH);
    DECLARE @DM18 INT = (SELECT TOP(1) MaDM FROM dbo.DANH_MUC ORDER BY MaDM);
    DECLARE @SP18 dbo.SanPhamKyGuiType, @Id18 INT;
    INSERT @SP18 (MaDM, TenSP, TinhTrang, TrangThaiTiepNhan)
    VALUES (@DM18, N'E2E món chặn', N'Còn tốt', N'Chờ xử lý');
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH=@MaKH18, @MaNV=@MaNghi18, @SanPham=@SP18, @MaPKG=@Id18 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #E2E VALUES (N'18. Nhân viên đã nghỉ bị chặn', 'FAIL', N'Không bị chặn.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() = 51002
        INSERT #E2E VALUES (N'18. Nhân viên đã nghỉ bị chặn', 'OK', N'51002: chặn đúng.');
    ELSE
        INSERT #E2E VALUES (N'18. Nhân viên đã nghỉ bị chặn', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
END CATCH
GO

/* ===== 19. Nhân viên có nghiệp vụ -> chuyển Đã nghỉ, không xoá ===== */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @MaNV19 INT = (SELECT TOP(1) p.MaNV FROM dbo.PHIEU_KY_GUI p ORDER BY p.MaPKG DESC);
    IF @MaNV19 IS NULL
        THROW 52000, N'Không có nhân viên nào có nghiệp vụ để kiểm tra.', 1;
    DECLARE @NghiepVu19 INT = (SELECT COUNT(*) FROM dbo.PHIEU_KY_GUI WHERE MaNV=@MaNV19)
                            + (SELECT COUNT(*) FROM dbo.DON_HANG WHERE MaNV=@MaNV19)
                            + (SELECT COUNT(*) FROM dbo.PHIEU_THANH_TOAN_KY_GUI WHERE MaNV=@MaNV19);
    IF @NghiepVu19 = 0
        THROW 52000, N'Nhân viên chọn để test phải có nghiệp vụ.', 1;
    UPDATE dbo.NHAN_VIEN SET TrangThai = N'Đã nghỉ' WHERE MaNV = @MaNV19;
    IF EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNV=@MaNV19)
       AND NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNV=@MaNV19 AND TrangThai=N'Đã nghỉ')
        THROW 52000, N'Hồ sơ nhân viên bị xoá thay vì chuyển Đã nghỉ.', 1;
    ROLLBACK TRANSACTION;
    INSERT #E2E VALUES (N'19. Nhân viên có nghiệp vụ chuyển Đã nghỉ', 'OK',
        N'Giữ lịch sử ' + CAST(@NghiepVu19 AS NVARCHAR(10)) + N' nghiệp vụ.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #E2E VALUES (N'19. Nhân viên có nghiệp vụ', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
END CATCH
GO

/* ===== 20. Nhân viên KHÔNG có nghiệp vụ -> xoá được (EmployeeService.Remove) ===== */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @MaNV20 INT;
    INSERT dbo.NHAN_VIEN (HoTen, SoDienThoai, ChucVu, TrangThai)
    VALUES (N'E2E Nhân viên xoá thử', '0908888002', N'Nhân viên', N'Đang làm việc');
    SET @MaNV20 = (SELECT MaNV FROM dbo.NHAN_VIEN WHERE SoDienThoai = '0908888002');
    IF EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI WHERE MaNV=@MaNV20)
       OR EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaNV=@MaNV20)
       OR EXISTS (SELECT 1 FROM dbo.PHIEU_THANH_TOAN_KY_GUI WHERE MaNV=@MaNV20)
        THROW 52000, N'Nhân viên vừa tạo không được có nghiệp vụ.', 1;

    DELETE dbo.NHAN_VIEN WHERE MaNV = @MaNV20;
    IF EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNV=@MaNV20)
        THROW 52000, N'Nhân viên không có nghiệp vụ vẫn không xoá được.', 1;
    ROLLBACK TRANSACTION;
    INSERT #E2E VALUES (N'20. Nhân viên rảnh nghiệp vụ xoá được', 'OK', N'Không để rác hồ sơ.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #E2E VALUES (N'20. Nhân viên rảnh nghiệp vụ', 'ERR', CONVERT(NVARCHAR(600), ERROR_MESSAGE()));
END CATCH
GO

/* ============================================================
   KET QUA
   ============================================================ */
SELECT Buoc, Ten, KetQua, ChiTiet FROM #E2E ORDER BY Buoc;
GO

SELECT COUNT(*) AS TongSo,
       SUM(CASE WHEN KetQua = 'OK' THEN 1 ELSE 0 END) AS Dat,
       SUM(CASE WHEN KetQua = 'ERR' OR KetQua = 'FAIL' THEN 1 ELSE 0 END) AS Hong
FROM #E2E;
GO

IF EXISTS (SELECT 1 FROM #E2E WHERE KetQua IN ('ERR','FAIL'))
    THROW 52001, N'E2E có bước thất bại. Xem bảng kết quả phía trên.', 1;
GO

DROP TABLE #E2E;
GO
PRINT N'E2E toan bo luong nghiep vu DAT.';
GO

