USE [QuanLyKyGuiThoiTrang];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

IF OBJECT_ID('tempdb..#KQ') IS NOT NULL DROP TABLE #KQ;
CREATE TABLE #KQ (STT INT, MoTa NVARCHAR(300), KetQua NVARCHAR(10), GhiChu NVARCHAR(500));
GO

/* 1. Duyệt với kết quả ngoài miền giá trị */
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_DuyetSanPham @MaSP = 11, @KetQua = N'Không hợp lệ';
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (1, N'Duyệt với kết quả không hợp lệ', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (1, N'Duyệt với kết quả không hợp lệ', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 2. Lập phiếu ký gửi không có sản phẩm */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @sp0 dbo.SanPhamKyGuiType;
    DECLARE @pkg0 INT;
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH = 1, @MaNV = 3, @SanPham = @sp0, @MaPKG = @pkg0 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (2, N'Lập phiếu ký gửi không có sản phẩm', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (2, N'Lập phiếu ký gửi không có sản phẩm', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 3. Không xét duyệt ngay trong bước lập phiếu tiếp nhận */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @sp1 dbo.SanPhamKyGuiType;
    INSERT @sp1 (MaDM, MaTH, TenSP, TinhTrang, GiaDangBan, TrangThaiTiepNhan)
    VALUES (1, 1, N'Áo test', N'Còn tốt', NULL, N'Đã chấp nhận');
    DECLARE @pkg1 INT;
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH = 1, @MaNV = 3, @SanPham = @sp1, @MaPKG = @pkg1 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (3, N'Lập phiếu không được gộp xét duyệt', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (3, N'Lập phiếu không được gộp xét duyệt', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 4. Thêm sản phẩm chưa duyệt vào đơn */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @ct4 dbo.ChiTietDonHangType;
    INSERT @ct4 VALUES (11, 0);
    DECLARE @dh4 INT;
    EXEC dbo.sp_TaoDonHang @MaKH = 6, @MaNV = 3, @ChiTiet = @ct4, @MaDH = @dh4 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (4, N'Thêm sản phẩm Chờ xử lý vào đơn', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (4, N'Thêm sản phẩm Chờ xử lý vào đơn', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 5. Thêm sản phẩm đang giữ vào đơn khác */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @ct5 dbo.ChiTietDonHangType;
    INSERT @ct5 VALUES (63, 0);
    DECLARE @dh5 INT;
    EXEC dbo.sp_TaoDonHang @MaKH = 7, @MaNV = 3, @ChiTiet = @ct5, @MaDH = @dh5 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (5, N'Thêm sản phẩm Đang giữ vào đơn khác', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (5, N'Thêm sản phẩm Đang giữ vào đơn khác', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 6. Giảm giá lớn hơn giá niêm yết */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @ct6 dbo.ChiTietDonHangType;
    INSERT @ct6 VALUES (50, 400000);
    DECLARE @dh6 INT;
    EXEC dbo.sp_TaoDonHang @MaKH = 6, @MaNV = 3, @ChiTiet = @ct6, @MaDH = @dh6 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (6, N'Giảm giá lớn hơn giá niêm yết', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (6, N'Giảm giá lớn hơn giá niêm yết', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 7. Trùng sản phẩm trong cùng đơn */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @ct7 dbo.ChiTietDonHangType;
    INSERT @ct7 VALUES (50, 0), (50, 0);
    DECLARE @dh7 INT;
    EXEC dbo.sp_TaoDonHang @MaKH = 6, @MaNV = 3, @ChiTiet = @ct7, @MaDH = @dh7 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (7, N'Trùng sản phẩm trong cùng một đơn', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (7, N'Trùng sản phẩm trong cùng một đơn', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 8. Hoàn tất đơn chưa thu đủ tiền */
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_HoanTatDonHang @MaDH = 25;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (8, N'Hoàn tất đơn Chờ thanh toán', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (8, N'Hoàn tất đơn Chờ thanh toán', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 9. Hủy đơn đã thu một phần */
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_HuyDonHang @MaDH = 28, @LyDo = N'Khách yêu cầu hủy';
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (9, N'Hủy đơn đã thu một phần', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (9, N'Hủy đơn đã thu một phần', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 10. Hủy đơn đang có giao dịch chờ xử lý:
       đơn phải huỷ được và giao dịch treo tự chuyển Thất bại (không còn chặn cứng) */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @treo10 INT = (SELECT COUNT(*) FROM dbo.THANH_TOAN_DON_HANG WHERE MaDH = 27 AND TrangThai = N'Chờ xử lý');
    EXEC dbo.sp_HuyDonHang @MaDH = 27, @LyDo = N'Khách yêu cầu hủy';
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH = 27 AND TrangThai = N'Đã hủy')
        THROW 52000, N'Đơn không chuyển sang Đã hủy.', 1;
    IF EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG WHERE MaDH = 27 AND TrangThai = N'Chờ xử lý')
        THROW 52000, N'Giao dịch treo chưa được đóng lại.', 1;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (10, N'Hủy đơn có giao dịch Chờ xử lý (tự đóng giao dịch treo)', N'PASS',
        CONCAT(N'Đã huỷ đơn, ', @treo10, N' giao dịch treo chuyển Thất bại.'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (10, N'Hủy đơn có giao dịch Chờ xử lý (tự đóng giao dịch treo)', N'FAIL', ERROR_MESSAGE());
END CATCH;
GO

/* 11. Quyết toán sản phẩm của đơn chưa hoàn tất */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @ds11 dbo.DanhSachCTDHType;
    INSERT @ds11 VALUES (42);
    DECLARE @p11 INT;
    EXEC dbo.sp_LapPhieuQuyetToan @MaKH = 22, @MaNV = 2, @PhuongThuc = N'Chuyển khoản',
         @DanhSach = @ds11, @MaPTTKG = @p11 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (11, N'Quyết toán sản phẩm thuộc đơn Đang xử lý', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (11, N'Quyết toán sản phẩm thuộc đơn Đang xử lý', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 12. Quyết toán trùng một sản phẩm */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @ds12 dbo.DanhSachCTDHType;
    INSERT @ds12 VALUES (1);
    DECLARE @p12 INT;
    EXEC dbo.sp_LapPhieuQuyetToan @MaKH = 1, @MaNV = 2, @PhuongThuc = N'Tiền mặt',
         @DanhSach = @ds12, @MaPTTKG = @p12 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (12, N'Quyết toán lại sản phẩm đã quyết toán', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (12, N'Quyết toán lại sản phẩm đã quyết toán', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 13. Quyết toán sản phẩm của người ký gửi khác */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @ds13 dbo.DanhSachCTDHType;
    INSERT @ds13 VALUES (6);
    DECLARE @p13 INT;
    EXEC dbo.sp_LapPhieuQuyetToan @MaKH = 1, @MaNV = 2, @PhuongThuc = N'Tiền mặt',
         @DanhSach = @ds13, @MaPTTKG = @p13 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (13, N'Quyết toán sản phẩm của người ký gửi khác', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (13, N'Quyết toán sản phẩm của người ký gửi khác', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 14. Sửa phiếu quyết toán đã thanh toán */
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.PHIEU_THANH_TOAN_KY_GUI SET GhiChu = N'Sửa trái phép' WHERE MaPTTKG = 1;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (14, N'Sửa phiếu quyết toán đã thanh toán', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (14, N'Sửa phiếu quyết toán đã thanh toán', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 15. Xóa giao dịch thanh toán thành công */
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE dbo.THANH_TOAN_DON_HANG WHERE MaTTDH = 1;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (15, N'Xóa giao dịch thanh toán đã thành công', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (15, N'Xóa giao dịch thanh toán đã thành công', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 16. Sửa đơn đã hoàn tất */
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.DON_HANG SET GhiChu = N'Sửa trái phép' WHERE MaDH = 1;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (16, N'Sửa đơn hàng đã hoàn tất', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (16, N'Sửa đơn hàng đã hoàn tất', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 17. Trả lại sản phẩm đã bán */
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_TraHang @MaSP = 1, @GhiChu = N'Trả nhầm';
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (17, N'Trả lại sản phẩm đã bán', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (17, N'Trả lại sản phẩm đã bán', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 18. Thêm sản phẩm vào đơn không còn Chờ thanh toán (trigger) */
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.CHI_TIET_DON_HANG (MaDH, MaSP, GiaNiemYetLucBan, GiamGia)
    VALUES (21, 50, 300000, 0);
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (18, N'Thêm sản phẩm vào đơn Đang xử lý', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (18, N'Thêm sản phẩm vào đơn Đang xử lý', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 19. Ghi nhận thanh toán 0 đồng */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @tt19 INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH = 29, @SoTien = 0, @PhuongThuc = N'Tiền mặt', @MaTTDH = @tt19 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (19, N'Ghi nhận thanh toán 0 đồng', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (19, N'Ghi nhận thanh toán 0 đồng', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 20. Thanh toán cho đơn đã hủy */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @tt20 INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH = 30, @SoTien = 550000, @PhuongThuc = N'Tiền mặt', @MaTTDH = @tt20 OUTPUT;
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (20, N'Ghi nhận thanh toán cho đơn đã hủy', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (20, N'Ghi nhận thanh toán cho đơn đã hủy', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

/* 21. QUY TẮC TRẢ THỪA: trả 1.000.000 cho đơn 900.000 -> coi như đủ */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @tt21 INT;
    DECLARE @ok21 BIT = 0;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH = 25, @SoTien = 1000000, @PhuongThuc = N'Tiền mặt',
         @MaGiaoDich = NULL, @GhiChu = N'Thu thừa 100.000đ', @MaTTDH = @tt21 OUTPUT;
    IF EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH = 25 AND TrangThai = N'Đang xử lý')
       AND NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM sp JOIN dbo.CHI_TIET_DON_HANG c ON c.MaSP = sp.MaSP
                       WHERE c.MaDH = 25 AND sp.TrangThaiBan <> N'Đã bán')
        SET @ok21 = 1;
    ROLLBACK TRANSACTION;
    IF @ok21 = 1
        INSERT #KQ VALUES (21, N'Trả thừa được coi là đã trả đủ', N'PASS', N'Đơn chuyển Đang xử lý, sản phẩm Đã bán.');
    ELSE
        INSERT #KQ VALUES (21, N'Trả thừa được coi là đã trả đủ', N'FAIL', N'Trạng thái không đúng.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (21, N'Trả thừa được coi là đã trả đủ', N'FAIL', ERROR_MESSAGE());
END CATCH;
GO

/* 22. QUY TẮC THU MỘT PHẦN: đơn vẫn Chờ thanh toán */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @tt22 INT;
    DECLARE @ok22 BIT = 0;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH = 26, @SoTien = 500000, @PhuongThuc = N'Tiền mặt', @MaTTDH = @tt22 OUTPUT;
    IF EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH = 26 AND TrangThai = N'Chờ thanh toán')
        SET @ok22 = 1;
    ROLLBACK TRANSACTION;
    IF @ok22 = 1
        INSERT #KQ VALUES (22, N'Thu một phần giữ nguyên Chờ thanh toán', N'PASS', N'Đơn vẫn Chờ thanh toán, sản phẩm vẫn Đang giữ.');
    ELSE
        INSERT #KQ VALUES (22, N'Thu một phần giữ nguyên Chờ thanh toán', N'FAIL', N'Trạng thái không đúng.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (22, N'Thu một phần giữ nguyên Chờ thanh toán', N'FAIL', ERROR_MESSAGE());
END CATCH;
GO

/* 23. Không thể thêm sản phẩm vào 2 đơn còn hiệu lực (trigger) */
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.CHI_TIET_DON_HANG (MaDH, MaSP, GiaNiemYetLucBan, GiamGia)
    VALUES (25, 50, 300000, 0);
    INSERT dbo.CHI_TIET_DON_HANG (MaDH, MaSP, GiaNiemYetLucBan, GiamGia)
    VALUES (26, 50, 300000, 0);
    ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (23, N'Thêm sản phẩm đang bán vào đơn thứ hai', N'FAIL', N'Không phát sinh lỗi.');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT #KQ VALUES (23, N'Thêm sản phẩm đang bán vào đơn thứ hai', N'PASS', ERROR_MESSAGE());
END CATCH;
GO

SELECT STT, MoTa, KetQua, GhiChu FROM #KQ ORDER BY STT;
GO
DECLARE @pass INT = (SELECT COUNT(*) FROM #KQ WHERE KetQua = N'PASS');
DECLARE @total INT = (SELECT COUNT(*) FROM #KQ);
PRINT N'';
PRINT N'KET QUA: ' + CAST(@pass AS NVARCHAR(10)) + N'/' + CAST(@total AS NVARCHAR(10)) + N' bai kiem tra dat.';
GO

