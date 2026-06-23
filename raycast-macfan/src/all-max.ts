import { showToast, Toast } from "@raycast/api";
import { setAllFansMaximum, toErrorMessage } from "./macfan";

export default async function Command() {
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: "Setting fans to Max"
  });

  try {
    const fanCount = await setAllFansMaximum();
    toast.style = Toast.Style.Success;
    toast.title = fanCount === 1 ? "Fan set to Max" : `${fanCount} fans set to Max`;
  } catch (error) {
    toast.style = Toast.Style.Failure;
    toast.title = "Could not set fans to Max";
    toast.message = toErrorMessage(error);
  }
}
