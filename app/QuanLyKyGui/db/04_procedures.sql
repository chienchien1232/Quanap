USE [QuanLyKyGuiThoiTrang];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================
   Dọn đối tượng cũ để chạy lại script an toàn
   ============================================================ */
DROP PROCEDURE IF EXISTS dbo.sp_TiepNhanPhieuKyGui;
DROP PROCEDURE IF EXISTS dbo.sp_DuyetSanPham;
DROP PROCEDURE IF EXISTS dbo.sp_DangBanSanPham;
DROP PROCEDURE IF EXISTS dbo.sp_TaoDonHang;
DROP PROCEDURE IF EXISTS dbo.sp_GhiNhanThanhToan;
DROP PROCEDURE IF EXISTS dbo.sp_HuyDonHang;
DROP PROCEDURE IF EXISTS dbo.sp_HoanTatDonHang;
DROP PROCEDURE IF EXISTS dbo.sp_LapPhieuQuyetToan;
DROP PROCEDURE IF EXISTS dbo.sp_ThanhToanPhieuKyGui;
DROP PROCEDURE IF EXISTS dbo.sp_TraHang;
DROP PROCEDURE IF EXISTS dbo.sp_TraCuuSanPham;
DROP PROCEDURE IF EXISTS dbo.sp_BaoCaoDoanhThu;
DROP PROCEDURE IF EXISTS dbo.sp_BaoCaoQuyetToan;
GO

IF TYPE_ID(N'dbo.SanPhamKyGuiType') IS NOT NULL DROP TYPE dbo.SanPhamKyGuiType;
IF TYPE_ID(N'dbo.ChiTietDonHangType') IS NOT NULL DROP TYPE dbo.ChiTietDonHangType;
IF TYPE_ID(N'dbo.DanhSachCTDHType') IS NOT NULL DROP TYPE dbo.DanhSachCTDHType;
GO

CREATE TYPE dbo.SanPhamKyGuiType AS TABLE
(
    MaDM              INT            NOT NULL,
    MaTH              INT            NULL,
    TenSP             NVARCHAR(200)  NOT NULL,
    MoTa              NVARCHAR(1000) NULL,
    KichThuoc         NVARCHAR(50)   NULL,
    MauSac            NVARCHAR(50)   NULL,
    ChatLieu          NVARCHAR(50)   NULL,
    TinhTrang         NVARCHAR(100)  NOT NULL,
    GiaDeXuat         DECIMAL(12,0)  NULL,
    GiaDangBan        DECIMAL(12,0)  NULL,
    TrangThaiTiepNhan NVARCHAR(20)   NOT NULL
);
GO

CREATE TYPE dbo.ChiTietDonHangType AS TABLE
(
    MaSP     INT           NOT NULL,
    GiamGia  DECIMAL(12,0) NOT NULL
);
GO

CREATE TYPE dbo.DanhSachCTDHType AS TABLE
(
    MaCTDH INT NOT NULL
);
GO

CREATE PROCEDURE dbo.sp_TiepNhanPhieuKyGui
    @MaKH INT,
    @MaNV INT,
    @NgayKyGui DATETIME2(0) = NULL,
    @GhiChu NVARCHAR(500) = NULL,
    @SanPham dbo.SanPhamKyGuiType READONLY,
    @MaPKG INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaKH = @MaKH)
        THROW 51001, N'Khách hàng không tồn tại.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNV = @MaNV AND TrangThai = N'Đang làm việc')
        THROW 51002, N'Nhân viên không tồn tại hoặc đã nghỉ việc.', 1;
    IF NOT EXISTS (SELECT 1 FROM @SanPham)
        THROW 51003, N'Phiếu ký gửi phải có ít nhất một sản phẩm.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE LEN(LTRIM(RTRIM(TenSP))) = 0)
        THROW 51004, N'Tên sản phẩm không được rỗng.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE LEN(LTRIM(RTRIM(TinhTrang))) = 0)
        THROW 51005, N'Tình trạng sản phẩm không được rỗng.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE TrangThaiTiepNhan <> N'Chờ xử lý')
        THROW 51006, N'Khi tiếp nhận, mọi sản phẩm phải ở trạng thái Chờ xử lý. Xét duyệt sau khi lưu phiếu.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE MaDM NOT IN (SELECT MaDM FROM dbo.DANH_MUC))
        THROW 51007, N'Danh mục sản phẩm không tồn tại.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE MaTH IS NOT NULL AND MaTH NOT IN (SELECT MaTH FROM dbo.THUONG_HIEU))
        THROW 51008, N'Thương hiệu sản phẩm không tồn tại.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE GiaDeXuat < 0)
        THROW 51009, N'Giá đề xuất không được âm.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE GiaDeXuat > 500000000)
        THROW 51012, N'Giá đề xuất không được vượt quá 500.000.000 đ.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE GiaDangBan IS NOT NULL)
        THROW 51011, N'Chưa nhập giá đăng bán ở bước tiếp nhận. Giá được chốt khi đăng bán.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT dbo.PHIEU_KY_GUI (MaKH, MaNV, NgayKyGui, TrangThai, GhiChu)
        VALUES (@MaKH, @MaNV, ISNULL(@NgayKyGui, SYSDATETIME()), N'Đang xử lý', @GhiChu);
        SET @MaPKG = CAST(SCOPE_IDENTITY() AS INT);
        INSERT dbo.SAN_PHAM
            (MaPKG, MaDM, MaTH, TenSP, MoTa, KichThuoc, MauSac, ChatLieu, TinhTrang,
             GiaDeXuat, GiaDangBan, TrangThaiTiepNhan, TrangThaiBan, NgayDangBan)
        SELECT @MaPKG, MaDM, MaTH, TenSP, MoTa, KichThuoc, MauSac, ChatLieu, TinhTrang,
               GiaDeXuat, NULL, N'Chờ xử lý', NULL, NULL
        FROM @SanPham;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- Xét duyệt không đăng bán và không bắt buộc có giá. Giữ chữ ký cũ để tương thích lời gọi.
CREATE PROCEDURE dbo.sp_DuyetSanPham
    @MaSP INT,
    @KetQua NVARCHAR(20),
    @GiaDangBan DECIMAL(12,0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @KetQua IS NULL OR @KetQua NOT IN (N'Đã chấp nhận', N'Từ chối')
        THROW 51103, N'Kết quả duyệt chỉ nhận Đã chấp nhận hoặc Từ chối.', 1;
    IF @GiaDangBan IS NOT NULL
        THROW 51104, N'Nhập giá ở bước đăng bán, không nhập giá trong thao tác xét duyệt.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TrangThai NVARCHAR(20);
        SELECT @TrangThai = TrangThaiTiepNhan
        FROM dbo.SAN_PHAM WITH (UPDLOCK, HOLDLOCK) WHERE MaSP = @MaSP;
        IF @TrangThai IS NULL
            THROW 51101, N'Sản phẩm không tồn tại.', 1;
        IF @TrangThai <> N'Chờ xử lý'
            THROW 51102, N'Chỉ được duyệt sản phẩm đang chờ xử lý. Hãy làm mới danh sách.', 1;
        IF EXISTS (
            SELECT 1 FROM dbo.CHI_TIET_DON_HANG c
            JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
            WHERE c.MaSP = @MaSP AND d.TrangThai <> N'Đã hủy'
        )
            THROW 51105, N'Không thể xét duyệt sản phẩm đang thuộc đơn hàng còn hiệu lực.', 1;

        UPDATE dbo.SAN_PHAM
        SET TrangThaiTiepNhan = @KetQua,
            TrangThaiBan = CASE WHEN @KetQua = N'Đã chấp nhận' THEN N'Chưa đăng bán' ELSE NULL END,
            GiaDangBan = NULL,
            NgayDangBan = NULL
        WHERE MaSP = @MaSP;
        -- Trigger TR_SAN_PHAM tổng hợp trạng thái phiếu từ tất cả sản phẩm.
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.sp_DangBanSanPham
    @MaSP INT,
    @GiaDangBan DECIMAL(12,0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TiepNhan NVARCHAR(20), @Ban NVARCHAR(20), @GiaHienTai DECIMAL(12,0);
        SELECT @TiepNhan = TrangThaiTiepNhan, @Ban = TrangThaiBan, @GiaHienTai = GiaDangBan
        FROM dbo.SAN_PHAM WITH (UPDLOCK, HOLDLOCK) WHERE MaSP = @MaSP;
        IF @TiepNhan IS NULL
            THROW 51201, N'Sản phẩm không tồn tại.', 1;
        IF @TiepNhan <> N'Đã chấp nhận'
            THROW 51202, N'Chỉ được đăng bán sản phẩm đã được xét duyệt chấp nhận.', 1;
        IF @Ban IS NULL OR @Ban NOT IN (N'Chưa đăng bán', N'Đang bán')
            THROW 51203, N'Chỉ đăng bán hoặc chỉnh giá sản phẩm Chưa đăng bán hoặc Đang bán.', 1;
        SET @GiaDangBan = ISNULL(@GiaDangBan, @GiaHienTai);
        IF @GiaDangBan IS NULL OR @GiaDangBan <= 0
            THROW 51204, N'Phải chốt giá đăng bán lớn hơn 0 trước khi đưa sản phẩm lên bán.', 1;
        IF @GiaDangBan > 500000000
            THROW 51205, N'Giá đăng bán không được vượt quá 500.000.000 đ.', 1;
        UPDATE dbo.SAN_PHAM
        SET GiaDangBan = @GiaDangBan, TrangThaiBan = N'Đang bán', NgayDangBan = ISNULL(NgayDangBan, SYSDATETIME())
        WHERE MaSP = @MaSP;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ============================================================
   sp_TaoDonHang - lập đơn và giữ hàng
   ============================================================ */
CREATE PROCEDURE dbo.sp_TaoDonHang
    @MaKH         INT,
    @MaNV         INT,
    @NgayLap      DATETIME2(0) = NULL,
    @HanThanhToan DATETIME2(0) = NULL,
    @GhiChu       NVARCHAR(500) = NULL,
    @ChiTiet      dbo.ChiTietDonHangType READONLY,
    @MaDH         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NgayLap = ISNULL(@NgayLap, SYSDATETIME());
    SET @HanThanhToan = ISNULL(@HanThanhToan, DATEADD(DAY, 3, @NgayLap));

    IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaKH = @MaKH)
        THROW 51301, N'Khách hàng không tồn tại.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNV = @MaNV AND TrangThai = N'Đang làm việc')
        THROW 51302, N'Nhân viên không tồn tại hoặc đã nghỉ việc.', 1;

    IF NOT EXISTS (SELECT 1 FROM @ChiTiet)
        THROW 51303, N'Đơn hàng phải có ít nhất một sản phẩm.', 1;

    IF @HanThanhToan < @NgayLap
        THROW 51304, N'Hạn thanh toán phải sau ngày lập đơn.', 1;

    IF EXISTS (SELECT 1 FROM @ChiTiet GROUP BY MaSP HAVING COUNT(*) > 1)
        THROW 51305, N'Một sản phẩm không được xuất hiện hai lần trong cùng đơn hàng.', 1;

    IF EXISTS (SELECT 1 FROM @ChiTiet WHERE GiamGia < 0)
        THROW 51306, N'Giảm giá không được âm.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @ChiTiet ct
        LEFT JOIN dbo.SAN_PHAM sp ON sp.MaSP = ct.MaSP
        WHERE sp.MaSP IS NULL
    )
        THROW 51307, N'Sản phẩm không tồn tại.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @ChiTiet ct
        JOIN dbo.SAN_PHAM sp ON sp.MaSP = ct.MaSP
        WHERE sp.TrangThaiBan IS NULL OR sp.TrangThaiBan <> N'Đang bán'
    )
        THROW 51308, N'Chỉ được thêm sản phẩm đang bán vào đơn hàng.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @ChiTiet ct
        JOIN dbo.SAN_PHAM sp ON sp.MaSP = ct.MaSP
        WHERE ct.GiamGia > sp.GiaDangBan
    )
        THROW 51309, N'Giảm giá không được lớn hơn giá niêm yết.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @ChiTiet ct
        JOIN dbo.CHI_TIET_DON_HANG c ON c.MaSP = ct.MaSP
        JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
        WHERE d.TrangThai <> N'Đã hủy'
    )
        THROW 51310, N'Sản phẩm đã thuộc một đơn hàng khác chưa hủy.', 1;

    BEGIN TRANSACTION;

    INSERT dbo.DON_HANG (MaKH, MaNV, NgayLap, HanThanhToan, TrangThai, LyDoHuy, GhiChu)
    VALUES (@MaKH, @MaNV, @NgayLap, @HanThanhToan, N'Chờ thanh toán', NULL, @GhiChu);

    SET @MaDH = CAST(SCOPE_IDENTITY() AS INT);

    INSERT dbo.CHI_TIET_DON_HANG (MaDH, MaSP, GiaNiemYetLucBan, GiamGia)
    SELECT @MaDH, ct.MaSP, sp.GiaDangBan, ct.GiamGia
    FROM @ChiTiet ct
    JOIN dbo.SAN_PHAM sp ON sp.MaSP = ct.MaSP;

    COMMIT TRANSACTION;
END
GO

/* ============================================================
   sp_GhiNhanThanhToan - ghi nhận một giao dịch thanh toán
   ============================================================ */
CREATE PROCEDURE dbo.sp_GhiNhanThanhToan
    @MaDH        INT,
    @SoTien      DECIMAL(12,0),
    @PhuongThuc  NVARCHAR(20),
    @TrangThai   NVARCHAR(20) = N'Thành công',
    @MaGiaoDich  VARCHAR(100) = NULL,
    @GhiChu      NVARCHAR(500) = NULL,
    @NgayTao     DATETIME2(0) = NULL,
    @MaTTDH      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NgayTao = ISNULL(@NgayTao, SYSDATETIME());

    DECLARE @TrangThaiDon NVARCHAR(20);
    DECLARE @TongTien DECIMAL(12,0);
    DECLARE @DaThu DECIMAL(12,0);

    SELECT @TrangThaiDon = TrangThai FROM dbo.DON_HANG WHERE MaDH = @MaDH;

    IF @TrangThaiDon IS NULL
        THROW 51401, N'Đơn hàng không tồn tại.', 1;

    IF @TrangThaiDon <> N'Chờ thanh toán'
        THROW 51402, N'Chỉ ghi nhận thanh toán cho đơn đang chờ thanh toán.', 1;

    IF @SoTien IS NULL OR @SoTien <= 0
        THROW 51403, N'Số tiền thanh toán phải lớn hơn 0.', 1;

    IF @PhuongThuc NOT IN (N'Tiền mặt', N'Chuyển khoản', N'Thẻ', N'Ví điện tử')
        THROW 51404, N'Phương thức thanh toán không hợp lệ.', 1;

    IF @TrangThai NOT IN (N'Chờ xử lý', N'Thành công', N'Thất bại')
        THROW 51405, N'Trạng thái giao dịch không hợp lệ.', 1;

    IF @TrangThai = N'Thành công'
    BEGIN
        SELECT @TongTien = ISNULL(SUM(GiaBanThucTe), 0)
        FROM dbo.CHI_TIET_DON_HANG
        WHERE MaDH = @MaDH;

        SELECT @DaThu = ISNULL(SUM(SoTien), 0)
        FROM dbo.THANH_TOAN_DON_HANG
        WHERE MaDH = @MaDH AND TrangThai = N'Thành công';

        IF @DaThu >= @TongTien
            THROW 51406, N'Đơn hàng đã được thanh toán đủ.', 1;
    END

    INSERT dbo.THANH_TOAN_DON_HANG
        (MaDH, SoTien, NgayTao, NgayHoanTat, PhuongThuc, TrangThai, MaGiaoDich, GhiChu)
    VALUES
        (@MaDH, @SoTien, @NgayTao,
         CASE WHEN @TrangThai = N'Thành công' THEN @NgayTao ELSE NULL END,
         @PhuongThuc, @TrangThai, @MaGiaoDich, @GhiChu);

    SET @MaTTDH = CAST(SCOPE_IDENTITY() AS INT);
END
GO

/* ============================================================
   sp_HuyDonHang - hủy đơn khi chưa có tiền
   ============================================================ */
CREATE PROCEDURE dbo.sp_HuyDonHang
    @MaDH  INT,
    @LyDo  NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TrangThai NVARCHAR(20);

    SELECT @TrangThai = TrangThai FROM dbo.DON_HANG WHERE MaDH = @MaDH;

    IF @TrangThai IS NULL
        THROW 51501, N'Đơn hàng không tồn tại.', 1;

    IF @TrangThai <> N'Chờ thanh toán'
        THROW 51502, N'Chỉ được hủy đơn đang chờ thanh toán.', 1;

    IF @LyDo IS NULL OR LEN(LTRIM(RTRIM(@LyDo))) = 0
        THROW 51503, N'Phải nhập lý do hủy đơn.', 1;

    IF EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG WHERE MaDH = @MaDH AND TrangThai = N'Thành công')
        THROW 51504, N'Không thể hủy đơn đã có thanh toán thành công.', 1;

    IF EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG WHERE MaDH = @MaDH AND TrangThai = N'Chờ xử lý')
        THROW 51505, N'Không thể hủy đơn đang có giao dịch thanh toán chờ xử lý.', 1;

    UPDATE dbo.DON_HANG
    SET TrangThai = N'Đã hủy',
        LyDoHuy = @LyDo
    WHERE MaDH = @MaDH;
END
GO

/* ============================================================
   sp_HoanTatDonHang - xác nhận đã bàn giao đủ
   ============================================================ */
CREATE PROCEDURE dbo.sp_HoanTatDonHang
    @MaDH INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TrangThai NVARCHAR(20);

    SELECT @TrangThai = TrangThai FROM dbo.DON_HANG WHERE MaDH = @MaDH;

    IF @TrangThai IS NULL
        THROW 51601, N'Đơn hàng không tồn tại.', 1;

    IF @TrangThai <> N'Đang xử lý'
        THROW 51602, N'Chỉ được hoàn tất đơn đang xử lý (đã thu đủ tiền).', 1;

    UPDATE dbo.DON_HANG
    SET TrangThai = N'Hoàn tất'
    WHERE MaDH = @MaDH;
END
GO

/* ============================================================
   sp_LapPhieuQuyetToan - lập phiếu trả tiền người ký gửi
   ============================================================ */
CREATE PROCEDURE dbo.sp_LapPhieuQuyetToan
    @MaKH        INT,
    @MaNV        INT,
    @PhuongThuc  NVARCHAR(20),
    @GhiChu      NVARCHAR(500) = NULL,
    @DanhSach    dbo.DanhSachCTDHType READONLY,
    @MaPTTKG     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaKH = @MaKH)
        THROW 51701, N'Khách hàng không tồn tại.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNV = @MaNV AND TrangThai = N'Đang làm việc')
        THROW 51702, N'Nhân viên không tồn tại hoặc đã nghỉ việc.', 1;

    IF @PhuongThuc NOT IN (N'Tiền mặt', N'Chuyển khoản')
        THROW 51703, N'Phương thức chi trả chỉ nhận Tiền mặt hoặc Chuyển khoản.', 1;

    IF NOT EXISTS (SELECT 1 FROM @DanhSach)
        THROW 51704, N'Phiếu quyết toán phải có ít nhất một sản phẩm.', 1;

    IF EXISTS (SELECT 1 FROM @DanhSach GROUP BY MaCTDH HAVING COUNT(*) > 1)
        THROW 51705, N'Một chi tiết đơn hàng không được xuất hiện hai lần.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @DanhSach ds
        LEFT JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = ds.MaCTDH
        WHERE c.MaCTDH IS NULL
    )
        THROW 51706, N'Chi tiết đơn hàng không tồn tại.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @DanhSach ds
        JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = ds.MaCTDH
        JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
        WHERE d.TrangThai <> N'Hoàn tất'
    )
        THROW 51707, N'Chỉ quyết toán sản phẩm thuộc đơn hàng đã hoàn tất.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @DanhSach ds
        JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = ds.MaCTDH
        JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
        JOIN dbo.PHIEU_KY_GUI pkg ON pkg.MaPKG = sp.MaPKG
        WHERE pkg.MaKH <> @MaKH
    )
        THROW 51708, N'Tất cả sản phẩm phải thuộc cùng người ký gửi.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @DanhSach ds
        JOIN dbo.CHI_TIET_THANH_TOAN_KY_GUI ct ON ct.MaCTDH = ds.MaCTDH
    )
        THROW 51709, N'Một sản phẩm chỉ được quyết toán một lần.', 1;

    BEGIN TRANSACTION;

    INSERT dbo.PHIEU_THANH_TOAN_KY_GUI
        (MaKH, MaNV, NgayLap, NgayThanhToan, PhuongThuc, TrangThai, MaGiaoDich, GhiChu)
    VALUES
        (@MaKH, @MaNV, SYSDATETIME(), NULL, @PhuongThuc, N'Chờ thanh toán', NULL, @GhiChu);

    SET @MaPTTKG = CAST(SCOPE_IDENTITY() AS INT);

    INSERT dbo.CHI_TIET_THANH_TOAN_KY_GUI (MaPTTKG, MaCTDH, GiaBanTinhToan)
    SELECT @MaPTTKG, c.MaCTDH, c.GiaBanThucTe
    FROM @DanhSach ds
    JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = ds.MaCTDH;

    COMMIT TRANSACTION;
END
GO

/* ============================================================
   sp_ThanhToanPhieuKyGui - xác nhận đã trả tiền người ký gửi
   ============================================================ */
CREATE PROCEDURE dbo.sp_ThanhToanPhieuKyGui
    @MaPTTKG    INT,
    @MaGiaoDich VARCHAR(100) = NULL,
    @GhiChu     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TrangThai NVARCHAR(20);

    SELECT @TrangThai = TrangThai FROM dbo.PHIEU_THANH_TOAN_KY_GUI WHERE MaPTTKG = @MaPTTKG;

    IF @TrangThai IS NULL
        THROW 51801, N'Phiếu quyết toán không tồn tại.', 1;

    IF @TrangThai <> N'Chờ thanh toán'
        THROW 51802, N'Phiếu quyết toán đã được thanh toán.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI WHERE MaPTTKG = @MaPTTKG)
        THROW 51803, N'Phiếu quyết toán không có chi tiết.', 1;

    UPDATE dbo.PHIEU_THANH_TOAN_KY_GUI
    SET TrangThai = N'Đã thanh toán',
        NgayThanhToan = SYSDATETIME(),
        MaGiaoDich = @MaGiaoDich,
        GhiChu = ISNULL(@GhiChu, GhiChu)
    WHERE MaPTTKG = @MaPTTKG;
END
GO

/* ============================================================
   sp_TraHang - trả sản phẩm chưa bán cho người ký gửi
   ============================================================ */
CREATE PROCEDURE dbo.sp_TraHang
    @MaSP INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TrangThaiTiepNhan NVARCHAR(20);
    DECLARE @TrangThaiBan NVARCHAR(20);

    SELECT @TrangThaiTiepNhan = TrangThaiTiepNhan,
           @TrangThaiBan = TrangThaiBan
    FROM dbo.SAN_PHAM
    WHERE MaSP = @MaSP;

    IF @TrangThaiTiepNhan IS NULL
        THROW 51901, N'Sản phẩm không tồn tại.', 1;

    IF @TrangThaiTiepNhan <> N'Đã chấp nhận'
        THROW 51902, N'Chỉ được trả lại sản phẩm đã chấp nhận.', 1;

    IF @TrangThaiBan NOT IN (N'Chưa đăng bán', N'Đang bán')
        THROW 51903, N'Chỉ được trả lại sản phẩm chưa đăng bán hoặc đang bán.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.CHI_TIET_DON_HANG c
        JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
        WHERE c.MaSP = @MaSP AND d.TrangThai <> N'Đã hủy'
    )
        THROW 51904, N'Không thể trả lại sản phẩm đang thuộc đơn hàng còn hiệu lực.', 1;

    UPDATE dbo.SAN_PHAM
    SET TrangThaiBan = N'Đã trả lại'
    WHERE MaSP = @MaSP;
END
GO

/* ============================================================
   sp_TraCuuSanPham - tìm kiếm sản phẩm theo nhiều tiêu chí
   ============================================================ */
CREATE PROCEDURE dbo.sp_TraCuuSanPham
    @TuKhoa       NVARCHAR(200) = NULL,
    @MaDM         INT = NULL,
    @MaTH         INT = NULL,
    @KichThuoc    NVARCHAR(50) = NULL,
    @TrangThaiBan NVARCHAR(20) = NULL,
    @MaKH         INT = NULL,
    @GiaTu        DECIMAL(12,0) = NULL,
    @GiaDen       DECIMAL(12,0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        MaSP, TenSP, TenDanhMuc, TenThuongHieu, KichThuoc, MauSac, ChatLieu, TinhTrang,
        GiaDeXuat, GiaDangBan, TrangThaiTiepNhan, TrangThaiBan, NgayDangBan,
        MaPKG, NgayKyGui, TrangThaiPhieu, MaKH, TenNguoiKyGui, DienThoaiNguoiKyGui,
        TenNhanVienTiepNhan
    FROM dbo.vw_SanPham_DayDu
    WHERE (@TuKhoa IS NULL OR TenSP LIKE N'%' + @TuKhoa + N'%'
                           OR TenThuongHieu LIKE N'%' + @TuKhoa + N'%'
                           OR TenNguoiKyGui LIKE N'%' + @TuKhoa + N'%')
      AND (@MaDM IS NULL OR MaDM = @MaDM)
      AND (@MaTH IS NULL OR MaTH = @MaTH)
      AND (@KichThuoc IS NULL OR KichThuoc = @KichThuoc)
      AND (@TrangThaiBan IS NULL OR TrangThaiBan = @TrangThaiBan)
      AND (@MaKH IS NULL OR MaKH = @MaKH)
      AND (@GiaTu IS NULL OR GiaDangBan >= @GiaTu)
      AND (@GiaDen IS NULL OR GiaDangBan <= @GiaDen)
    ORDER BY NgayDangBan DESC, MaSP DESC;
END
GO

/* ============================================================
   sp_BaoCaoDoanhThu - doanh thu theo tháng
   ============================================================ */
CREATE PROCEDURE dbo.sp_BaoCaoDoanhThu
    @TuNgay  DATE,
    @DenNgay DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @TuNgay IS NULL OR @DenNgay IS NULL OR @TuNgay > @DenNgay
        THROW 52001, N'Khoảng thời gian báo cáo không hợp lệ.', 1;

    SELECT
        CONVERT(varchar(7), d.NgayLap, 126) AS Thang,
        COUNT(DISTINCT d.MaDH) AS SoDon,
        COUNT(*) AS SoSanPham,
        SUM(c.GiaBanThucTe) AS DoanhThu,
        SUM(dbo.fn_HoaHong(c.GiaBanThucTe)) AS TienHoaHong,
        SUM(dbo.fn_ThucNhan(c.GiaBanThucTe)) AS TienTraNguoiKyGui
    FROM dbo.DON_HANG d
    JOIN dbo.CHI_TIET_DON_HANG c ON c.MaDH = d.MaDH
    WHERE d.TrangThai = N'Hoàn tất'
      AND d.NgayLap >= CAST(@TuNgay AS DATETIME2(0))
      AND d.NgayLap < DATEADD(DAY, 1, CAST(@DenNgay AS DATETIME2(0)))
    GROUP BY CONVERT(varchar(7), d.NgayLap, 126)
    ORDER BY Thang;
END
GO

/* ============================================================
   sp_BaoCaoQuyetToan - báo cáo quyết toán cho người ký gửi
   ============================================================ */
CREATE PROCEDURE dbo.sp_BaoCaoQuyetToan
    @MaKH       INT = NULL,
    @TuNgay     DATE = NULL,
    @DenNgay    DATE = NULL,
    @TrangThai  NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @TuNgay IS NOT NULL AND @DenNgay IS NOT NULL AND @TuNgay > @DenNgay
        THROW 52101, N'Khoảng thời gian báo cáo không hợp lệ.', 1;

    IF @TrangThai IS NOT NULL AND @TrangThai NOT IN (N'Chưa quyết toán', N'Chờ thanh toán', N'Đã thanh toán')
        THROW 52102, N'Trạng thái quyết toán không hợp lệ.', 1;

    SELECT
        MaCTDH, MaDH, NgayLap, MaSP, TenSP, KichThuoc, MauSac,
        MaKH, TenNguoiKyGui, SoDienThoai,
        GiaBan, TienHoaHong, TienThucNhan,
        MaCTTTKG, MaPTTKG, TrangThaiQuyetToan, NgayLapPhieu, NgayThanhToan
    FROM dbo.vw_QuyetToan_SanPham
    WHERE (@MaKH IS NULL OR MaKH = @MaKH)
      AND (@TuNgay IS NULL OR NgayLap >= CAST(@TuNgay AS DATETIME2(0)))
      AND (@DenNgay IS NULL OR NgayLap < DATEADD(DAY, 1, CAST(@DenNgay AS DATETIME2(0))))
      AND (@TrangThai IS NULL OR TrangThaiQuyetToan = @TrangThai)
    ORDER BY TenNguoiKyGui, NgayLap, MaCTDH;
END
GO

PRINT N'Procedures created: 13 procedures + 3 table types.';
GO
