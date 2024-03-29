require "test_helper"

class ReportsHelperTest < ActionView::TestCase
  test "#format_date returns date (DD/MM/YYYY)" do
    date = Date.new(2024, 3, 7)
    result = format_date(date)
    assert_equal "07/03/2024", result
  end

  test "#concat_names returns a string of names" do
    collection = [ users(:joe), users(:ron) ]
    result = concat_names(collection)
    assert_equal "Joe Doe, Ron Done", result
  end

  test "#concat_names returns a string, based on a custom method" do
    collection = [ users(:joe), users(:ron) ]
    result = concat_names(collection, "last_name")
    assert_equal "Doe, Done", result
  end

  test "#time_frame returns human readable date range" do
    start_date = Date.new(2023, 3, 7)
    end_date = Date.new(2024, 6, 28)
    result = time_frame(start_date, end_date)
    assert_equal "07/03/2023 - 28/06/2024", result
  end

  test "#time_frame returns 'All time'" do
    result = time_frame(nil, nil)
    assert_equal "All time", result
  end
end
